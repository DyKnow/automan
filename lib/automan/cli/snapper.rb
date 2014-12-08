require 'automan'
require 'time'

module Automan::Cli
  class Snapper < Base

    desc "create", "create a snapshot"

    option :environment,
      aliases: "-e",
      desc: "environment of database to snapshot"

    option :database,
      aliases: "-d",
      desc: "name of the database to snapshot"

    option :name,
      aliases: "-n",
      desc: "what to name the snapshot"

    option :prune,
      aliases: "-p",
      type: :boolean,
      default: true,
      desc: "make this snapshot prunable and delete other prunable snapshots older than 30 days"

    option :wait_for_completion,
      aliases: "-w",
      type: :boolean,
      default: false,
      desc: "wait until snapshot is finished before exiting script"

    def create
      if options[:database].nil? && options[:environment].nil?
        puts "Must specify either database or environment"
        help "create"
        exit 1
      end

      s = Automan::RDS::Snapshot.new(options)
      s.log_aws_calls = true
      s.prune_snapshots if options[:prune]
      s.create
    end

    desc "delete", "delete a snapshot"

    option :name,
      required: true,
      aliases: "-n",
      desc: "name of snapshot to delete"

    def delete
      Automan::RDS::Snapshot.new(options).delete
    end

    desc "latest", "find the most recent snapshot"

    option :database,
      aliases: "-d",
      desc: "name of the database to snapshot"

    option :environment,
      aliases: "-e",
      desc: "environment of database to snapshot"

    def latest
      if options[:database].nil? && options[:environment].nil?
        puts "Must specify either database or environment"
        help "latest"
        exit 1
      end

      Automan::RDS::Snapshot.new(options).latest
    end

  end
end