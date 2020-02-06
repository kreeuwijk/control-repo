#!/usr/bin/env python3

import os
import sys
import time
import json
import logging
import argparse
import base64
import requests
from cd4pe_client import CD4PE

CD4PE_CLIENT = None
parser       = argparse.ArgumentParser(description='Optional app description')
parser.add_argument('--commitSha', type=str, help='the Git commit SHA to check')
parser.add_argument('--maxchanges', type=int, help='how many changes are still deemed safe', default=10)
parser.add_argument('--stagename', type=str, help='the pipeline stage to report')
parser.add_argument('--changereq', type=bool, help='(boolean) create a SNOW ticket for deploy approval', default=False)
parser.add_argument('--user', type=str, help='the CD4PE username')
parser.add_argument('--pwd', type=str, help='the CD4PE user password')
parser.add_argument('--endpoint', type=str, help='the CD4PE endpoint')
parser.add_argument('--repo', type=str, help='the (control)repo to parse')

args       = parser.parse_args()
commitSha  = args.commitSha
maxchanges = args.maxchanges
stagename  = args.stagename
changereq  = args.changereq
user       = args.user
pwd        = args.pwd
endpoint   = args.endpoint
repo       = args.repo
LOGGER     = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

def print_json(content):
    print(json.dumps(content, indent=2))

def add2log(content):
    print(content)
    if data['log'] == "":
        data['log'] = content
    else:
        data['log'] = data['log'] + "\n" + content

def connect_cd4pe(endpoint, username, password):
    global CD4PE_CLIENT
    CD4PE_CLIENT = CD4PE(endpoint, True)
    CD4PE_CLIENT.login(email=username, passwd=password)

def search_latest_pipeline(repo_name, gitCommitId):
    response = CD4PE_CLIENT.list_trigger_events(repo_name=repo_name).json()
    for x in range(len(response['rows'])):
        if response['rows'][x]['commitId'] == gitCommitId:
            result = {}
            result['id'] = response['rows'][x]['pipelineId']
            result['eventId'] = response['rows'][x]['id']
            add2log( "Pipeline #: " + str(result['eventId']))
            response = None
            return result

def switcher_jobstatus(job_status):
    switcher = {
        'f': "Failure",
        's': "Success"
    }
    return switcher.get(job_status, "unknown status: " + str(job_status))

def report_pipeline_stages(pipeline_json, pipeline_stage):
    no_of_stages = len(pipeline_json['stages'])
    add2log("Number of stages in pipeline: " + str(no_of_stages))
    for x in range(no_of_stages):
        stage_failure = False
        stage = pipeline_json['stages'][x]
        if stage['stageName'] == pipeline_stage:
            add2log("Stage " + str(stage['stageNum']) + ": " + stage['stageName'] )
            data['build']['queue_id'] = stage['stageNum']
            no_of_stage_jobs = len(stage['destinations'])
            add2log("  Number of jobs in stage: " + str(no_of_stage_jobs))
            for y in range(no_of_stage_jobs):
                stage_job = stage['destinations'][y]
                eventinfo = {}
                if 'vmJobEvent' in stage_job:
                    add2log("  Job name: " + stage_job['vmJobEvent']['jobName'])
                    add2log("  Job status: " + switcher_jobstatus(stage_job['vmJobEvent']['jobStatus']))
                    eventinfo['eventName'] = stage_job['vmJobEvent']['jobName']
                    eventinfo['eventNumber'] = stage_job['vmJobEvent']['vmJobInstanceId']
                    eventinfo['eventTime'] = stage_job['vmJobEvent']['eventTime']
                    eventinfo['eventResult'] = switcher_jobstatus(stage_job['vmJobEvent']['jobStatus'])
                    eventinfo['startTime'] = stage_job['vmJobEvent'].get('jobStartTime', stage_job['vmJobEvent']['jobEndTime'])
                    eventinfo['endTime'] = stage_job['vmJobEvent']['jobEndTime']
                    eventinfo['executionTime'] = (eventinfo['endTime'] - eventinfo['startTime'])/1000
                    data['build']['events'].append(eventinfo) 
                    if switcher_jobstatus(stage_job['vmJobEvent']['jobStatus']) != 'Success':
                        stage_failure = True
                elif 'deploymentAppEvent' in stage_job:
                    add2log("  Deployment: " + stage_job['deploymentAppEvent']['deploymentPlanName'] + " to " + stage_job['deploymentAppEvent']['targetBranch'])
                    add2log("  Deployment status: " + stage_job['deploymentAppEvent']['deploymentState'] )
                    eventinfo['eventName'] = stage_job['deploymentAppEvent']['deploymentPlanName'] + " to " + stage_job['deploymentAppEvent']['targetBranch']
                    eventinfo['eventNumber'] = stage_job['deploymentAppEvent']['deploymentId']
                    eventinfo['eventTime'] = stage_job['deploymentAppEvent']['eventTime']
                    eventinfo['eventResult'] = stage_job['deploymentAppEvent']['deploymentState']
                    eventinfo['startTime'] = stage_job['deploymentAppEvent']['deploymentEndTime'] if stage_job['deploymentAppEvent']['deploymentStartTime'] == 0 else stage_job['deploymentAppEvent']['deploymentStartTime']
                    eventinfo['endTime'] = stage_job['deploymentAppEvent']['deploymentEndTime']
                    eventinfo['executionTime'] = (eventinfo['endTime'] - eventinfo['startTime'])/1000
                    data['build']['events'].append(eventinfo) 
                    if stage_job['deploymentAppEvent']['deploymentState'] != 'DONE':
                        stage_failure = True
                elif 'peImpactAnalysisEvent' in stage_job:
                    add2log("  Impact Analysis: on " + str(len(stage_job['peImpactAnalysisEvent']['environments'])) + " environments")
                    add2log("  Impact Analysis status: " + stage_job['peImpactAnalysisEvent']['state'])
                    eventinfo['eventName'] = "Impact Analysis on " + str(len(stage_job['peImpactAnalysisEvent']['environments'])) + " environments"
                    eventinfo['eventNumber'] = stage_job['peImpactAnalysisEvent']['impactAnalysisId']
                    eventinfo['eventTime'] = stage_job['peImpactAnalysisEvent']['eventTime']
                    eventinfo['eventResult'] = stage_job['peImpactAnalysisEvent']['state']
                    eventinfo['startTime'] = stage_job['peImpactAnalysisEvent'].get('startTime', stage_job['peImpactAnalysisEvent']['endTime'])
                    eventinfo['endTime'] = stage_job['peImpactAnalysisEvent']['endTime']
                    eventinfo['executionTime'] = (eventinfo['endTime'] - eventinfo['startTime'])/1000
                    data['build']['events'].append(eventinfo) 
                    if stage_job['peImpactAnalysisEvent']['state'] != 'DONE':
                        stage_failure = True
            first_event = data['build']['events'][0]
            last_event = data['build']['events'][-1]
            data['build']['timestamp'] = first_event['eventTime']
            data['build']['startTime'] = first_event['startTime']
            data['build']['endTime'] = last_event['endTime']
            data['build']['executionTime'] = (last_event['endTime'] - first_event['startTime'])/1000
            if stage_failure == True:
                result = "Stage failed"
                data['build']['status'] = 'FAILURE'
            else:
                result = "Stage succeeded"
                data['build']['status'] = 'SUCCESS'
            add2log(result)
            return result

def get_IA_from_pipeline(pipeline_json):
    no_of_stages = len(pipeline_json['stages'])
    for x in range(no_of_stages):
        stage = pipeline_json['stages'][x]
        no_of_stage_jobs = len(stage['destinations'])
        for y in range(no_of_stage_jobs):
            stage_job = stage['destinations'][y]
            if 'peImpactAnalysisEvent' in stage_job:
                table = {}
                table['Id'] = stage_job['peImpactAnalysisEvent']['impactAnalysisId']
                table['Status'] = stage_job['peImpactAnalysisEvent']['state']
                return table

def get_impact_analysis_node_report(impact_analysis_id, max_changes):
    # TODO: make environment an argument of the function and process only that environment
    response = CD4PE_CLIENT.get_impact_analysis(id=impact_analysis_id).json()
    no_of_environments = len(response['results'])
    for x in range(no_of_environments):
        table = {}
        env_result = response['results'][x]
        add2log("Impact Analysis report on environment: " + env_result['environment'])
        table['IA_environment'] = env_result['environment']
        env_result_id = env_result['environmentResultId']
        env_result = None
        env_result = CD4PE_CLIENT.search_impacted_nodes(environment_result_id=env_result_id).json()
        no_of_impacted_nodes = len(env_result['rows'])
        add2log( "Number of impacted nodes: " + str(no_of_impacted_nodes))
        safe_report = True
        table['IA_nodes_impacted'] = len(env_result['rows'])
        compile_failures = 0
        compile_success = 0
        table['IA_node_reports'] = {}
        for y in range(no_of_impacted_nodes):
            node_result = env_result['rows'][y]
            table['IA_node_reports'][node_result['certnameLowercase']] = {}
            if 'compileFailed' in node_result:
                add2log("  Node " + node_result['certnameLowercase'] + ": Failed compilation")
                compile_failures += 1
                table['IA_node_reports'][node_result['certnameLowercase']]['Compilation'] = 'FAILED'
                safe_report = False
            else:
                add2log("  Node " + node_result['certnameLowercase'] + " resources: " +
                    str(len(node_result['resourcesAdded'])) + " added, " +
                    str(len(node_result['resourcesModified'])) + " modified, " +
                    str(len(node_result['resourcesRemoved'])) + " removed.")
                compile_success += 1
                table['IA_node_reports'][node_result['certnameLowercase']]['compilation'] = 'SUCCESS'
                table['IA_node_reports'][node_result['certnameLowercase']]['resourcesAdded'] = len(node_result['resourcesAdded'])
                table['IA_node_reports'][node_result['certnameLowercase']]['resourcesModified'] = len(node_result['resourcesModified'])
                table['IA_node_reports'][node_result['certnameLowercase']]['resourcesRemoved'] = len(node_result['resourcesRemoved'])
                table['IA_node_reports'][node_result['certnameLowercase']]['totalResourcesChanges'] = len(node_result['resourcesAdded']) + len(node_result['resourcesModified']) + len(node_result['resourcesRemoved'])
                if table['IA_node_reports'][node_result['certnameLowercase']]['totalResourcesChanges'] > max_changes:
                    table['IA_node_reports'][node_result['certnameLowercase']]['change_verdict'] = 'unsafe'
                    safe_report = False
                else:
                    table['IA_node_reports'][node_result['certnameLowercase']]['change_verdict'] = 'safe'
        table['IA_compile_failures'] = compile_failures
        table['IA_compile_success'] = compile_success
        if safe_report == True:
            table['IA_verdict'] = 'safe'
            add2log('Impact Analysis: safe')
        else:
            table['IA_verdict'] = 'unsafe'
            add2log('Impact Analysis: unsafe')
        response = None
        return table

def get_pending_approvals(pipeline_json):
    no_of_stages = len(pipeline_json['stages'])
    table = {}
    for x in range(no_of_stages):
        stage = pipeline_json['stages'][x]
        no_of_stage_jobs = len(stage['destinations'])
        for y in range(no_of_stage_jobs):
            stage_job = stage['destinations'][y]
            if 'deploymentAppEvent' in stage_job:
                deployment = CD4PE_CLIENT.get_deployment(id=stage_job['deploymentAppEvent']['deploymentId']).json()
                if deployment['deploymentState'] == 'PENDING_APPROVAL':
                    table[deployment['environmentForPendingApproval']] = deployment['id']
    return table

def request_snow_change(endpoint, deployment_id):
    headers = {'Content-Type': 'application/json'}
    json = {}
    json['commitSHA'] = pipeline_json['buildStage']['imageEvent']['commitId']
    json['deploymentId'] = deployment_id
    json['targetBranch'] = 'production'
    print_json(json)
    #webhook_response = requests.post(endpoint, headers=headers, json=json)
    #print(webhook_response)

def trigger_webhook(endpoint, data):
    headers = {'Content-Type': 'application/json'}
    webhook_response = requests.post(endpoint, headers=headers, json=data)
    print(webhook_response)

# Start of code execution
data = {}
data['log'] = ""
connect_cd4pe(endpoint=endpoint, username=user, password=pwd)
pipeline = search_latest_pipeline(repo_name=repo, gitCommitId=commitSha)
if changereq:
    time.sleep(60)

pipeline_json = CD4PE_CLIENT.get_pipeline(repo_name=repo, pipeline_id=pipeline['id']).json()

if changereq:
    pending_approvals = get_pending_approvals(pipeline_json=pipeline_json)
    request_snow_change(endpoint='https://ven02941.service-now.com/api/x_radi_rapdev_pupp/change_request', deployment_id=pending_approvals['production'])
else:
    data['name'] = 'cd4pe-pipeline'
    data['display_name'] = 'cd4pe-pipeline'
    data['build'] = {}
    data['build']['events'] = []
    data['notes'] = ""
    data['url'] = "main/repositories/" + repo + "?pipelineId=" + str(pipeline['id'])
    data['build']['full_url'] = endpoint + "/" + CD4PE_CLIENT.api_ajax.owner + "/repositories/" + repo + "?pipelineId=" + str(pipeline['id']) + "&eventId=" + str(pipeline['eventId'])
    data['build']['number'] = pipeline['eventId']
    data['build']['phase'] = stagename
    data['build']['url'] = "/" + CD4PE_CLIENT.api_ajax.owner + "/repositories/" + repo + "?pipelineId=" + str(pipeline['id']) + "&eventId=" + str(pipeline['eventId'])
    data['scm'] = {}
    data['scm']['url'] = pipeline_json['buildStage']['imageEvent']['repoUrl']
    data['scm']['branch'] = pipeline_json['buildStage']['imageEvent']['branch']
    data['scm']['commit'] = pipeline_json['buildStage']['imageEvent']['commitId']
    data['scm']['changes'] = []
    data['scm']['culprits'] = []
    data['artifacts'] = {}

    pipeline_report = report_pipeline_stages(pipeline_json=pipeline_json, pipeline_stage=stagename)
    if stagename == 'Impact Analysis':
        IA = get_IA_from_pipeline(pipeline_json=pipeline_json)
        if IA['Status'] == "DONE":
            report = get_impact_analysis_node_report(impact_analysis_id=IA['Id'], max_changes=maxchanges)
            data['notes'] = report

    print_json(data)

    #trigger_webhook(endpoint='https://ven02941.service-now.com/api/x_radi_rapdev_pupp/pipeline_webhook', data=data)