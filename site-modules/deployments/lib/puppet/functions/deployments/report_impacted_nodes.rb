# frozen_string_literal: true

Puppet::Functions.create_function(:'deployments::report_impacted_nodes') do
  dispatch :report_impacted_nodes do
    required_param 'Hash', :impacted_nodes
    required_param 'Integer', :max_changes_per_node
  end

  def add2log(content)
    print(content + "\n")
    @report['log'] = if @report['log'] == ''
                       content
                     else
                       @report['log'] + "\n" + content
                     end
  end

  def report_impacted_nodes(impacted_nodes, max_changes_per_node)
    @report = {}
    @report['log'] = ''
    @report['IA_node_reports'] = []
    @report['IA_nodes_impacted'] = impacted_nodes['rows'].count
    compile_failures = 0
    compile_success = 0
    bln_safe_report = true
    impacted_nodes['rows'].each do |node_result|
      @report['IA_node_reports'][node_result['certnameLowercase']] = {}
      if node_result.key?('compileFailed')
        add2log('   Node ' + node_result['certnameLowercase'] + ': Failed compilation')
        compile_failures += 1
        @report['IA_node_reports'][node_result['certnameLowercase']]['Compilation'] = 'FAILED'
        bln_safe_report = false
      else
        add2log('   Node ' + node_result['certnameLowercase'] + " resources: \n" \
          '    ' + node_result['resourcesAdded'].count.to_s + " added, \n" \
          '    ' + node_result['resourcesModified'].count.to_s + " modified, \n" \
          '    ' + node_result['resourcesRemoved'].count.to_s + ' removed.')
        compile_success += 1
        @report['IA_node_reports'][node_result['certnameLowercase']]['compilation'] = 'SUCCESS'
        @report['IA_node_reports'][node_result['certnameLowercase']]['resourcesAdded'] = node_result['resourcesAdded'].count.to_i
        @report['IA_node_reports'][node_result['certnameLowercase']]['resourcesModified'] = node_result['resourcesModified'].count.to_i
        @report['IA_node_reports'][node_result['certnameLowercase']]['resourcesRemoved'] = node_result['resourcesRemoved'].count.to_i
        @report['IA_node_reports'][node_result['certnameLowercase']]['totalResourcesChanges'] = (
          node_result['resourcesAdded'].count.to_i +
          node_result['resourcesModified'].count.to_i +
          node_result['resourcesRemoved'].count.to_i
        )
        if @report['IA_node_reports'][node_result['certnameLowercase']]['totalResourcesChanges'] > max_changes_per_node
          @report['IA_node_reports'][node_result['certnameLowercase']]['change_verdict'] = 'unsafe'
          bln_safe_report = false
        else
          @report['IA_node_reports'][node_result['certnameLowercase']]['change_verdict'] = 'safe'
        end
      end
    end
    @report['IA_compile_failures'] = compile_failures
    @report['IA_compile_success'] = compile_success
    if bln_safe_report == true
      @report['IA_verdict'] = 'safe'
      add2log('  Impact Analysis: safe')
    else
      @report['IA_verdict'] = 'unsafe'
      add2log('  Impact Analysis: unsafe')
    end
    @report
  end
end
