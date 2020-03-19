# frozen_string_literal: true

Puppet::Functions.create_function(:'deployments::report_impact_analysis') do
  dispatch :report_impact_analysis do
    required_param 'Hash', :impact_analysis
  end

  def add2log(content)
    print(content + "\n")
    @report['log'] = if @report['log'] == ''
                       content
                     else
                       @report['log'] + "\n" + content
                     end
  end

  def report_impact_analysis(impact_analysis)
    @report = {}
    @report['log'] = ''
    @report['results'] = []
    @report['id'] = impact_analysis['id']
    @report['state'] = impact_analysis['state']
    impact_analysis['results'].each do |env_result|
      result_report = {}
      result_report['IA_environment'] = env_result['environment']
      result_report['IA_resultId'] = env_result['environmentResultId']
      result_report['IA_nodeGroupId'] = env_result['nodeGroupId']
      result_report['IA_state'] = env_result['state']
      result_report['IA_totalNodeCount'] = env_result['totalNodeCount']
      result_report['IA_totalResourceChangeCount'] = env_result['totalResourceChangeCount']
      add2log(' Impact Analysis report on environment: ' + result_report['IA_environment'])
      add2log('  Impact Analysis state: ' + result_report['IA_state'])
      add2log('  Total Nodes affected: ' + result_report['IA_totalNodeCount'].to_s)
      add2log('  Total Resources affected: ' + result_report['IA_totalResourceChangeCount'].to_s)
      @report['results'].append(result_report)
    end
    @report
  end
end
