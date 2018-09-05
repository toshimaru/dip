# frozen_string_literal: true

require 'shellwords'
require_relative '../command'
require_relative 'compose'

module Dip
  module Commands
    class Run < Dip::Command
      def initialize(cmd, subcmd = nil, argv = [], run_vars: nil)
        @cmd = cmd.to_sym
        @subcmd = subcmd.to_sym if subcmd
        @argv = argv
        @run_vars = run_vars
        @config = ::Dip.config.interaction
      end

      def execute
        command = @config.fetch(@cmd)
        command[:subcommands] ||= {}

        if (subcommand = command[:subcommands].fetch(@subcmd, {})).any?
          subcommand[:command] ||= nil
          command.merge!(subcommand)
        else
          @argv.unshift(@subcmd.to_s) if @subcmd
        end

        Dip.env.merge(command[:environment]) if command[:environment]

        compose_method = command.fetch(:compose_method, "run").to_s

        compose_argv = []
        compose_argv.concat(prepare_compose_run_options(command[:compose_run_options]))
        compose_argv.concat(run_vars)
        compose_argv << "--rm" if compose_method == "run"
        compose_argv << command.fetch(:service).to_s
        compose_argv += command[:command].to_s.shellsplit
        compose_argv.concat(@argv)

        Dip::Commands::Compose.new(compose_method, compose_argv).execute
      end

      def prepare_compose_run_options(value)
        return [] unless value

        value.map do |o|
          o = o.start_with?("-") ? o : "--#{o}"
          o.shellsplit
        end.flatten
      end

      def run_vars
        return [] unless @run_vars

        @run_vars.map { |k, v| ["-e", "#{k}=#{v}"] }.flatten
      end
    end
  end
end
