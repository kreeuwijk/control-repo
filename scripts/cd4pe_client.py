import logging
from urllib.parse import urlparse
import requests

# pylint: disable=too-many-public-methods
class CD4PE:

    def __init__(self, endpoint, quiet=False):
        self.endpoint = endpoint
        self.setup_logging(quiet)
        self.session = {'username': None, 'cookie': self.get_anon_cookie()}

    def setup_logging(self, quiet):
        logger = logging.getLogger('cd4pe_client')
        logger.setLevel(logging.DEBUG)
        console_handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        if quiet:
            logger.setLevel(logging.ERROR)
        else:
            logger.setLevel(logging.DEBUG)

        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
        self.logger = logger

    def get_anon_cookie(self):
        return requests.get(self.endpoint).cookies.get_dict()

    # pylint: disable=invalid-name
    def api(self, resource, op=None, content=None, params=None, method="post"):
        data = {}
        if op:
            data['op'] = op
        if content:
            data['content'] = content
        headers = {
            'Content-Type': 'application/json'
        }

        if method.lower() == "get":
            if not params:
                params = {}
            params['op'] = op
        if params:
            resource += '?' + urlencode(params)

        self.logger.info("CD4PE api: -> %s %s (%s)",
                         method.upper(), op, self.endpoint + resource)
        self.logger.debug("CD4PE session: -> %s", self.session)

        try:
            if method.lower() == "post":
                self.logger.debug("CD4PE api: -> %s", data)
                response = requests.post(self.endpoint + resource,
                                         headers=headers, json=data, cookies=self.session['cookie'])
            else:
                response = requests.get(self.endpoint + resource,
                                        headers=headers, cookies=self.session['cookie'])
            self.logger.info("CD4PE api: <- %s %s",
                             response.status_code, response.text)
        except requests.exceptions.HTTPError as err:
            self.logger.info("CD4PE api: <- %s %s",
                             response.status_code, response.reason)
            raise err

        return response

    def api_ajax(self, op=None, params=None, content=None, method="post"):
        if not self.session or not self.session['username']:
            raise Exception('No logged in user, cannot perform operation')
        owner = self.session['workspace'] if 'workspace' in self.session else self.session['username']
        resource = '/' + owner + '/ajax'
        return self.api(resource=resource, op=op, params=params, content=content, method=method)

    def login(self, email, passwd):
        response = self.api(resource='/login', op='PfiLogin',
                            content={'email': email, 'passwd': passwd})
        cookie = response.cookies.get_dict()
        self.session = {
            'username': response.json()['username'], 'cookie': cookie}
        self.logger.debug("CD4PE login: %s", self.session)
        json = response.json()
        if 'redirectTo' in json:
            redirectUri = response.json()['redirectTo']
            workspace = redirectUri.split("/")[1]
            self.session['workspace'] = workspace
            self.logger.debug(
                "CD4PE login - setting workspace to: %s", workspace)

        return response

    def logout(self):
        response = self.api(resource='/logout', op='PfiLogout')
        self.session = {'username': None,
                        'cookie': response.cookies.get_dict()}
        return response
    
    def list_trigger_events(self, repo_name):
        return self.api_ajax(params={'repoName': repo_name}, op="ListTriggerEvents", method='get')

    def get_pipeline(self, repo_name, pipeline_id):
        return self.api_ajax(params={'controlRepoName': repo_name, 'pipelineId': pipeline_id}, op="GetPipeline", method='get')

    def get_impact_analysis(self, id):
        return self.api_ajax(params={'id': id}, op="GetImpactAnalysis", method='get')

    def search_impacted_nodes(self, environment_result_id):
        return self.api_ajax(params={'environmentResultId': environment_result_id}, op="SearchImpactedNodes", method='get')

    def get_deployment(self, id):
        return self.api_ajax(params={'id': id}, op="GetDeployment", method='get')
    
    def approve_deployment(self, deployment_id):
        return self.api_ajax(content={'deploymentId': deployment_id, "approvalDecision": "APPROVED", "deploymentType": "CONTROL_REPOSITORY"}, op="SetDeploymentApproval")
