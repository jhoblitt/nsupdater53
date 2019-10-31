#!/usr/bin/env ruby

nsfile = ARGV.first
zone_id = ARGV[1]

Record = Struct.new(:name, :ttl, :type, :value)

def parse_record(line)
  # "update add _kerberos-master._tcp.lsst.cloud. 86400 IN SRV 0 100 88 ipamaster1.tuc.lsst.cloud.\n"
  line.match(/^update add (?<name>\S+) (?<ttl>\d+) IN (?<type>\S+) (?<value>.*)$/) { |m|
    return Record.new(*m.captures)
  }
end

recs = []
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

    recs << parse_record(line)
  end
end

recs.each { |r|
  tmpl = <<~HCL
    resource "aws_route53_record" "#{r.name}" {
      zone_id = "#{zone_id}"

      name    = "#{r.name}"
      type    = "#{r.type}"
      ttl     = "#{r.ttl}"
      records = ["#{r.value}"]
    }

  HCL

  puts tmpl
}
