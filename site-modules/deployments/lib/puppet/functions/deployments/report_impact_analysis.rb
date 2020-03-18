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
      result_report['environment'] = env_result['environment']
      result_report['resultId'] = env_result['environmentResultId']
      result_report['nodeGroupId'] = env_result['nodeGroupId']
      result_report['state'] = env_result['state']
      result_report['totalNodeCount'] = env_result['totalNodeCount']
      result_report['totalResourceChangeCount'] = env_result['totalResourceChangeCount']
      add2log(' Impact Analysis report on environment: ' + result_report['environment'])
      add2log('  Impact Analysis state: ' + result_report['state'])
      add2log('  Total Nodes affected: ' + result_report['totalNodeCount'].to_s)
      add2log('  Total Resources affected: ' + result_report['totalResourceChangeCount'].to_s)
      @report['results'].append(result_report)
    end
    @report
  end
end
