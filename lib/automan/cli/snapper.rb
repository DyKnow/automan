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

    option :type,
      aliases: "-t",
      desc: "type of snapshot. When pruning, only snapshots of the specified type will be deleted."

    option :max_snapshots,
      aliases: "-m",
      desc: "Maximum number of snapshots of this type to retain",
      type: :numeric

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

      if options[:prune]
        if options[:type].nil? || options[:max_snapshots].nil?
          puts "Must specify snapshot type and max snapshots to retain when pruning"
          help "create"
          exit 1
        end
      end

      aws_opts = options.dup
      aws_opts[:log_aws] = true
      s = Automan::RDS::Snapshot.new(aws_opts)
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

    desc "count", "return the number of snapshots"

    option :environment,
      aliases: "-e",
      desc: "environment of database to snapshot"

    option :database,
      aliases: "-d",
      desc: "name of the database to snapshot"

    def count
      if options[:database].nil? && options[:environment].nil?
        puts "Must specify either database or environment"
        help "count"
        exit 1
      end

      Automan::RDS::Snapshot.new(options).count_snapshots
    end

  end
end
