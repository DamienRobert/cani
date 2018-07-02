# frozen_string_literal: true

require 'colorize'
require 'json'
require 'yaml'

require 'cani/version'
require 'cani/config'
require 'cani/api'
require 'cani/feature'
require 'cani/browser'

# Cani
module Cani
  def self.config(**opts)
    @settings ||= Config.new(**opts)
  end

  def self.api
    @api ||= Api.new
  end

  def self.help
    puts "Cani #{VERSION} <https://github.com/SidOfc/cani>"
    puts ''
    puts 'Usage: cani [COMMAND [ARGUMENTS]] [OPTIONS]'
    puts ''
    puts 'Commands:'
    puts '   use FEATURE             show browser support for FEATURE'
    puts '   show BROWSER            show information about specific browser'
    puts '   list TYPE               list names of each item in TYPE'
    puts '                           TYPE can be "features" or "browsers"'
    puts ''
    puts 'Options:'
    puts '   -h   --help             show this help'
    puts '   -v   --version          print the version number'
    puts ''
    puts 'Examples:'
    puts '   cani -h'
    puts '   cani --version'
    puts '   cani use box-shadow'
    puts '   cani show ie'
    puts '   cani list features'

    exit
  end

  def self.find_browser(name)
    name = name.to_s.downcase
    idx  = api.browsers.find_index { |bwsr| bwsr.title.downcase == name }

    api.browsers[idx] if idx
  end

  def self.run(cmd = nil)
    cmd ||= config.args.first

    if cmd && respond_to?(cmd)
      send cmd
    else
      cmd = fzf([['show', 'Show browser info'],
                 ['use', 'Show feature info'],
                 ['edit', 'Edit the default config using $EDITOR']],
                 header: ['commands']).first

      if cmd
        run cmd
      end
    end
  end

  def self.fzf_rows(rows, **opts)
    col_widths = []
    colors     = opts.fetch(:colors, [])

    rows.each do |row|
      row.each.with_index do |column, i|
        col_width     = column.size
        col_widths[i] = col_width if col_width > col_widths[i].to_i
      end
    end

    rows.map do |row|
      row.map.with_index do |col, i|
        result = col.to_s.ljust(col_widths[i])

        if output_is_pipe?
          result.colorize(colors[i] || colors[-1] || :default)
                .gsub('"', '\"')
        else
          result
        end
      end.join('   ').rstrip
    end
  end

  def self.edit
    system(ENV.fetch('EDITOR', 'vim'), config.default)
  end

  def self.fzf(rows, **opts)
    if STDOUT.tty?
      rows   = fzf_rows(rows, **opts).join("\n")
      ohdr   = opts.fetch(:header, [])
      header = ohdr.is_a?(Array) ? [:cani, *ohdr].map { |v| v.to_s.downcase }.join(':')
                                 : 'cani:' + ohdr.to_s

      `echo "#{rows}" | fzf --ansi --header="[#{header}]"`.split('   ')
    else
      puts fzf_rows(rows).join("\n")

      # in this case, we want to exit immediately after printing the result since it was
      # piped to another command like "cat" or "grep".
      exit
    end
  end

  def self.output_is_pipe?
    @@output_is_pipe ||= STDIN.tty?
  end

  def self.use_fmt(ft)
    st = config.statuses.fetch ft.status, ft.status
    pc = format('%.2f%%', ft.percent).rjust(6)
    tt = format('%-24s', ft.title.size > 24 ? ft.title[0..23].strip + '..'
                                            : ft.title)

    ["[#{st}]", pc, tt, *ft.current_support]
  end

  def self.use(feature = config.args[1])
    puts fzf(api.features.map(&method(:use_fmt)),
             header: 'use]   [' + Feature.support_legend,
             colors: %i[green light_black light_white light_black])
  end

  def self.show_browser_fmt(features_by_support)
    Feature::TYPES.flat_map do |(status, type)|
      if (features = features_by_support.fetch(type, nil))
        features.map do |feature|
          st = config.statuses.fetch feature[:status], feature[:status]

          ["[#{st}]", "[#{Feature::SYMBOLS[status]}]", feature[:title]]
        end
      end
    end.compact
  end

  def self.show(brws = config.args[1], version = config.args[2])
    browser = find_browser brws

    if browser
      if version
        fzf show_browser_fmt(browser.features_for(version)),
          header: "show:#{browser.title.downcase}:#{version}]   [#{Feature.support_legend}",
            colors: [:green, :light_black, :light_white]

        show browser.title, nil
      else
        rows = browser.usage.map { |(v, u)| [v, 'usage: ' + format('%.4f%%', u)] }.reverse

        if (version = fzf(rows, header: [:show, browser.title],
                                colors: %i[white light_black]).first)
          show browser.title, version
        else
          show nil, nil
        end
      end
    else
      rows    = api.browsers.map { |bwsr| [bwsr.title, 'usage: ' + format('%.4f%%', bwsr.usage.values.sum)] }
      browser = find_browser fzf(rows, header: [:show], colors: %i[white light_black]).first

      show browser.title, nil unless browser.nil?
    end
  end
end
