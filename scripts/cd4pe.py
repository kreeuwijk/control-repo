#!/usr/bin/env python

import os
import sys
import time
import json
import logging
import argparse
import base64
from cd4pe_client import CD4PE

CD4PE_CLIENT = None
parser       = argparse.ArgumentParser(description='Optional app description')
parser.add_argument('--commitSha', type=str, help='the Git commit SHA to check')
parser.add_argument('--stagename', type=str, help='the pipeline stage to report')
parser.add_argument('--user', type=str, help='the CD4PE username')
parser.add_argument('--pwd', type=str, help='the CD4PE user password')
parser.add_argument('--endpoint', type=str, help='the CD4PE endpoint')
parser.add_argument('--repo', type=str, help='the (control)repo to parse')

args      = parser.parse_args()
commitSha = args.commitSha
stagename = args.stagename
user      = args.user
pwd       = args.pwd
endpoint  = args.endpoint
repo      = args.repo
LOGGER    = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

def print_json(content):
    print(json.dumps(content, indent=2))

def connect_cd4pe(endpoint, username, password):
    global CD4PE_CLIENT
    CD4PE_CLIENT = CD4PE(endpoint, True)
    CD4PE_CLIENT.login(email=username, passwd=password)

def search_latest_pipeline(repo_name, gitCommitId):
    response = CD4PE_CLIENT.list_trigger_events(repo_name=repo_name).json()
    for x in range(len(response['rows'])):
        if response['rows'][x]['commitId'] == gitCommitId:
            pipeline_id = response['rows'][x]['pipelineId']
            print( "Pipeline #: " + str(response['rows'][x]['id']) )
            response = None
            return pipeline_id

def switcher_jobstatus(job_status):
    switcher = {
        'f': "Failure",
        's': "Success"
    }
    return switcher.get(job_status, "unknown status: " + str(job_status))

def report_pipeline_stages(repo_name, pipeline_id, pipeline_stage):
    response = CD4PE_CLIENT.get_pipeline(repo_name=repo_name, pipeline_id=pipeline_id).json()
    no_of_stages = len(response['stages'])
    print("Number of stages in pipeline: " + str(no_of_stages))
    for x in range(no_of_stages):
        stage_failure = False
        stage = response['stages'][x]
        if stage['stageName'] == pipeline_stage:
            print("Stage " + str(stage['stageNum']) + ": " + stage['stageName'] )
            no_of_stage_jobs = len(stage['destinations'])
            print("  Number of jobs in stage: " + str(no_of_stage_jobs))
            for y in range(no_of_stage_jobs):
                stage_job = stage['destinations'][y]
                if 'vmJobEvent' in stage_job:
                    print("  Job name: " + stage_job['vmJobEvent']['jobName'])
                    print("  Job status: " + switcher_jobstatus(stage_job['vmJobEvent']['jobStatus']))
                    if switcher_jobstatus(stage_job['vmJobEvent']['jobStatus']) != 'Success':
                        stage_failure = True
                elif 'deploymentAppEvent' in stage_job:
                    print("  Deployment: " + stage_job['deploymentAppEvent']['deploymentPlanName'] + " to " + stage_job['deploymentAppEvent']['targetBranch'])
                    print("  Deployment status: " + stage_job['deploymentAppEvent']['deploymentState'] )
                    if stage_job['deploymentAppEvent']['deploymentState'] != 'DONE':
                        stage_failure = True
                elif 'peImpactAnalysisEvent' in stage_job:
                    print("  Impact Analysis: on " + str(len(stage_job['peImpactAnalysisEvent']['environments'])) + " environments")
                    print("  Impact Analysis status: " + stage_job['peImpactAnalysisEvent']['state'])
                    if stage_job['peImpactAnalysisEvent']['state'] != 'DONE':
                        stage_failure = True
            result = "Stage succeeded" if (stage_failure == False) else "Stage failed"
            print(result)
            response = None
            return result

def get_IA_from_pipeline(repo_name, pipeline_id):
    response = CD4PE_CLIENT.get_pipeline(repo_name=repo_name, pipeline_id=pipeline_id).json()
    no_of_stages = len(response['stages'])
    for x in range(no_of_stages):
        stage = response['stages'][x]
        no_of_stage_jobs = len(stage['destinations'])
        for y in range(no_of_stage_jobs):
            stage_job = stage['destinations'][y]
            if 'peImpactAnalysisEvent' in stage_job:
                table = {}
                table['Id'] = stage_job['peImpactAnalysisEvent']['impactAnalysisId']
                table['Status'] = stage_job['peImpactAnalysisEvent']['state']
                return table

def get_impact_analysis_node_report(impact_analysis_id):
    # TODO: make environment an argument of the function and process only that environment
    response = CD4PE_CLIENT.get_impact_analysis(id=impact_analysis_id).json()
    no_of_environments = len(response['results'])
    for x in range(no_of_environments):
        env_result = response['results'][x]
        print("Impact Analysis report on environment: " + env_result['environment'])
        env_result_id = env_result['environmentResultId']
        env_result = CD4PE_CLIENT.search_impacted_nodes(environment_result_id=env_result_id).json()
        no_of_impacted_nodes = len(env_result['rows'])
        print( "Number of impacted nodes: " + str(no_of_impacted_nodes))
        safe_report = True
        for y in range(no_of_impacted_nodes):
            node_result = env_result['rows'][y]
            if 'compileFailed' in node_result:
                print("  Node " + node_result['certnameLowercase'] + ": Failed compilation")
                safe_report = False
            else:
                print("  Node " + node_result['certnameLowercase'] + " resources: " +
                    str(len(node_result['resourcesAdded'])) + " added, " +
                    str(len(node_result['resourcesModified'])) + " modified, " +
                    str(len(node_result['resourcesRemoved'])) + " removed.")
        result = "Impact Analysis: safe" if (safe_report == True) else "Impact Analysis: unsafe"
        print(result)
        response = None
        return result

def get_pending_approvals(repo_name, pipeline_id):
    response = CD4PE_CLIENT.get_pipeline(repo_name=repo_name, pipeline_id=pipeline_id).json()
    no_of_stages = len(response['stages'])
    table = {}
    for x in range(no_of_stages):
        stage = response['stages'][x]
        no_of_stage_jobs = len(stage['destinations'])
        for y in range(no_of_stage_jobs):
            stage_job = stage['destinations'][y]
            if 'deploymentAppEvent' in stage_job:
                deployment = CD4PE_CLIENT.get_deployment(id=stage_job['deploymentAppEvent']['deploymentId']).json()
                if deployment['deploymentState'] == 'PENDING_APPROVAL':
                    table[deployment['environmentForPendingApproval']] = deployment['id']
    return table

def approve_deployment(deployment_id):
    response = CD4PE_CLIENT.approve_deployment(deployment_id=deployment_id).json()
    return response

# Start of code execution
connect_cd4pe(endpoint=endpoint, username=user, password=pwd)
pipeline_id = search_latest_pipeline(repo_name=repo, gitCommitId=commitSha)
pipeline_report = report_pipeline_stages(repo_name=repo, pipeline_id=pipeline_id, pipeline_stage=stagename)
