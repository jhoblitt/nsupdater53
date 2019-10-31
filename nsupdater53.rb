#!/usr/bin/env ruby

nsfile = ARGV.first
zone_id = ARGV[1]

Record = Struct.new(:name, :ttl, :type, :value)

def parse_cmd(line)
  # "update add _kerberos-master._tcp.lsst.cloud. 86400 IN SRV 0 100 88 ipamaster1.tuc.lsst.cloud.\n"
  line.match(/^update add (?<name>\S+) (?<ttl>\d+) IN (?<type>\S+) (?<value>.*)$/) { |m|
    r = Record.new(*m.captures)

    # remove quotes from TXT records
    if m['type'] == 'TXT'
      r.value = m['value'].gsub(/"/, '')
    end

    return  r
  }
end

# merge the value of multiple nsupdate commands that are applying to the same
# SRV record
def merge_records(cmds)
  # flat list of records
  recs = []

  cmds.each { |name, set|
    if set.length > 1
      values = set.collect { |r| r.value }.join("\n")
      r = set.first
      recs << Record.new(
        name,
        r.ttl,
        r.type,
        values,
      )
    else
      recs << set.first
    end
  }

  return recs
end

# Hash of Lists of commands
cmds = {}

File.open(nsfile, "r") do |file_handle|
  file_handle.each_line do |line|
    # skip comment lines
    next if line =~ /^\s*;/
    # skip blank lines
    next if line =~ /^\s*$/
    # skip "send" lines
    next if line =~ /^\s*send/
    # skip "update delete" lines
    next if line =~ /^\s*update delete/

    r = parse_cmd(line)
    if cmds.key?(r.name)
      cmds[r.name] << r
      next
    else
      cmds[r.name] = [r]
    end
  end
end

# flat List of records
recs = merge_records(cmds)

recs.each { |r|
  sanitized_name = r.name.dup
  # tf does not like `.` in resource names
  sanitized_name.tr!('.', '_')

  tmpl = <<~HCL
    resource "aws_route53_record" "#{sanitized_name}" {
      zone_id = "#{zone_id}"

      name    = "#{r.name}"
      type    = "#{r.type}"
      ttl     = "#{r.ttl}"
      records = [#{r.value.dump}]
    }

  HCL

  puts tmpl
}
