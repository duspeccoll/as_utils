#!/usr/bin/env ruby

# this is eventually going to be an ArchivesSpace date cleanup script, but right
# now it just writes a list of the dates it *would* be fixing to stdout

require 'date'
require_relative 'astools'

# meses del año
@months = /(January|February|March|April|May|June|July|August|September|October|November|December)/

# validation regex
@dacs_date = /^((((((before|after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?(((\[)?\d{4}s(\])?)|(\d+(st|nd|th)(-\d+(st|nd|th))?\scentury)))|((\[)?\d{4}(\])?(\s#{@months}(\s\d+(-\d+)?)?)?)))|((((between|circa|before)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)\scentury)))|((\[)?\d{4}(\])?(\s#{@months}(\s\d+)?)?))-((after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)\scentury)))|((\[)?\d{4}(\])?(\s#{@months}(\s\d+)?)?)))|(((between|circa|before)\s)?(\[)?\d{4}(\])?\s#{@months}(\s\d+)?-((after|circa)\s)?#{@months}(\s\d+)?)|(((between|circa)\s)?(\[)?\d{4}(\])?\s#{@months}\s\d+-\d+)))((,|\sor)\s((((before|after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?\d{4}s)|((\[)?\d{4}(\])?(\s#{@months}(\s\d+)?)?)))|(((between|circa|before)\s)?((\d{4}(s|(\s#{@months}(\s\d+)?))?-(after)?\d{4}(s|(\s#{@months}(\s\d+)?))?)|(\d{4}\s#{@months}(\s\d+)?-#{@months}(\s\d+)?)|(\d{4}\s#{@months}\s\d+-\d+)))))?( and undated)?)|various dates)$/
@single_date = /^(before|after|circa )?(\[)?\d{4}((\])?\s#{@months}(\s\d(\d)?)?)?$/

# hashes and arrays for cleanup tasks
@approx = ["circa", "before", "after", "between", "early", "mid", "late"]
undateds = ["Date Not Yet Determined", "UNKNOWN", "Unknown", "unknown", "N/A", "n.d.", "no date", "Undated", "undated"]

# hash to spell out month abbreviations
@mos = {
  /Jan\./ => "January",
  /Feb\./ => "February",
  /Mar\./ => "March",
  /Apr\./ => "April",
  /Jun\s/ => "June ",
  /Jul\s/ => "July ",
  /Aug\./ => "August",
  /Sept\./ => "September",
  /Oct\./ => "October",
  /Nov\./ => "November",
  /Dec\./ => "December"
}

log = "date_cleanup_log.txt"

# check if a date validates against that monstrous DACS validation regexp
def is_dacs?(str)
  return true if @dacs_date.match(str)
  false
end

# all our pre-processing clean-up tasks
def cleanup(str)
  str.strip!

  # fix punctuation
  str.gsub!(/\s(-|to|(-)?and(?! undated))\s/,"-")
  str = str.gsub(/\s?-\s?/,"-").gsub(/(;\s|\s,\s)/,", ").gsub(/\s\s+?/," ").gsub(/'s/,"s").gsub(/^(\s+?|FY\s)/,"").gsub(/\s&\s/,", ")
  str.gsub!(/^c{1}(a|\.)(\.|\s)?\s?/,"circa ")
  str.gsub!(/,/,", ") if /,\d/.match(str)

  # downcase and spell check
  @approx.each {|dstr| str.gsub!(/#{dstr.capitalize}/,"#{dstr}")}
  str.gsub!(/(betwen|betweem|beetween|betweeen)/,"between")
  str.gsub!(/between/,"between ") if /between\d/.match(str)
  str.gsub!(/, (U|u)ndated/, " and undated") if /, (U|u)ndated$/.match(str)
  str.gsub!(/^Various (D|d)ates$/, "various dates")

  # insert or modify date range prefixes (before, after, circa)
  str = "after #{str.gsub(/-/,'')}" if str.end_with?("-")
  str = "after #{str.gsub(/-Present/,'')}" if str.end_with?("-Present")
  str = "after #{str.gsub(/-Unknown/, '')}" if str.end_with?("-Unknown")
  str = "before #{str.gsub(/-/,'')}" if str.start_with?("-")
  str = "circa #{str.gsub(/\?/,'')}" if str.end_with?("?")
  str.gsub!(/^Around/,"circa") if str.start_with?("Around")

  str
end

def set_range_date(str)
  str = str.gsub(/s$/,'').gsub(/(before|after) /,'').gsub(/(\[|\])/,'')
  date = case
  when /^\d{4}$/.match(str)
    str
  when /^\d{4}\s#{@months}$/.match(str)
    Date.strptime(str, '%Y %B').strftime("%Y-%m")
  when /^\d{4}\s#{@months}\s\d(\d)?$/.match(str)
    Date.strptime(str, '%Y %B %d').strftime("%Y-%m-%d")
  end

  date
end

def set_begin_date(str)
  date = ""
  pre = str.scan(/\w+/)[0]
  if /^(\w+? )?\d{4}s/.match(str)
    root = str.gsub(/\w+\s/,'')
    date = case
    when pre == "before"
      ""
    when pre.start_with?("mid")
      root.gsub(/\ds$/,'3')
    when pre.start_with?("late")
      root.gsub(/\ds$/,'5')
    else
      root.gsub(/\ds$/,'0')
    end
  elsif /century$/.match(str)
    int = (str.scan(/\d+/)[0].to_i)-1
    date = case
    when str.start_with?("mid")
      "#{int.to_s}30"
    when str.start_with?("late")
      "#{int.to_s}50"
    else
      "#{int.to_s}00"
    end
  elsif pre == "before"
    date = ""
  else
    date = set_range_date(str)
  end

  date
end

def set_end_date(str)
  date = ""
  pre = str.scan(/\w+/)[0]
  if pre == "after"
    date = ""
  elsif /^(\w+?\s)?\d{4}s$/.match(str)
    root = str.gsub(/\w+\s/,'')
    date = case
    when pre.start_with?("early")
      "#{root.gsub(/\ds$/,'4')}"
    when pre.start_with?("mid")
      "#{root.gsub(/\ds$/,'7')}"
    else
      "#{root.gsub(/\ds$/,'9')}"
    end
  elsif /century$/.match(str)
    int = (str.scan(/\d+/)[0].to_i)-1
    date = case
    when str.start_with?("early")
      "#{int.to_s}49"
    when str.start_with?("mid")
      "#{int.to_s}79"
    else
      "#{int.to_s}99"
    end
  else
    date = set_range_date(str)
  end

  date
end

def set_range_dates(str)
  range = {}
  range['date_type'] = @single_date.match(str) ? "single" : "inclusive"
  range['certainty'] = "approximate" if @approx.include?(str)
  str = str.gsub(/circa /,'').gsub(/ and undated/,'').gsub(/between /,'')

  if /,/.match(str)
    expr = str.split(/,/)
    range['begin'] = /-/.match(expr.first) ? set_begin_date(expr.first.split(/-/)[0]) : set_begin_date(expr.first)
    range['end'] = /-/.match(expr.last) ? set_end_date(expr.last.split(/-/)[1]) : set_end_date(expr.last.lstrip)
  else
    if /-/.match(str)
      expr = str.split(/-/)

      # add the decade back to "early-mid" or "mid-late" begin dates
      expr[0] = "#{expr[0]} #{expr[1].scan(/\d{4}s/)[0]}" if /^(early|mid)$/.match(expr[0])

      # add the month and/or date back to end dates with limited ranges
      if /^#{@months}/.match(expr[1])
        expr[1] = "#{expr[0].scan(/\d{4}/)[0]} #{expr[1]}"
      elsif /^\d(\d)?$/.match(expr[1])
        expr[1] = "#{expr[0].gsub(/\d(\d)?$/,'')}#{expr[1]}"
      end

      range['begin'] = set_begin_date(expr[0])
      range['end'] = set_end_date(expr[1])
    else
      range['begin'] = set_begin_date(str)
      range['end'] = set_end_date(str) unless range['date_type'] == "single"
    end
  end

  range
end

# this does the cleanup for single dates
def fix_single_date(str)
  str = str.gsub(/\/0\//,'/')
  @mos.each {|k,v| str.gsub!(k,v) if /^#{k}/.match(str)}

  # set aside any time-modifying prefix (between, circa, etc.) for later
  if /^\w+\s/.match(str)
    unless /^#{@months}/.match(str)
      pre = str.scan(/\w+/)[0]
      str.gsub!(/^\w+\s/,'')
    end
  end

  # slash dates excluding a date, e.g. "1/2015"
  if /^\d(\d)?\/\d{4}$/.match(str)
    str = DateTime.strptime(str, '%m/%Y').strftime("%Y %B")

  # academic year dates, e.g. "1994/95"
  elsif /^\d{4}(\/|-)\d{2}$/.match(str)
    str = "#{str[0,4]}-#{str[0,2]}#{str[5,2]}"

  # date ranges within a single month, e.g. "January 1-14 1995"
  elsif /^#{@months}\s\d+-\d+(,)?\s\d{4}$/.match(str)
    str.gsub!(/,/,'')
    month = str.scan(/\w+/)[0]
    date = str.scan(/\d+-\d+/)[0]
    str.gsub!(/^\w+\s\d+-\d+\s/,'')
    str = "#{str} #{month} #{date}"

  # slash date ranges within a single month, e.g. "1/1-14/1995"
  elsif /^\d(\d)?\/\d(\d)?-\d(\d)?\/\d{4}$/.match(str)
    expr = str.split(/\//)
    str = "#{expr[2]} #{DateTime.strptime(expr[0], '%m').strftime("%B")} #{expr[1].gsub(/0(\d{1})/,'\1')}"

  # months or month ranges within a single year, e.g. "January 1995" or "January-March 1995"
  elsif /^#{@months}(-#{@months})?(,)?\s\d{4}/.match(str)
    str.gsub!(/,/,'')
    year = str.scan(/\d{4}/)[0]
    str = "#{year} #{str.gsub!(/\s\d{4}$/,'')}"

  # slash date month ranges within a single year, e.g. "01-03/1995"
  elsif /^\d{2}-\d{2}\/\d{4}$/.match(str)
    year = str.scan(/\d{4}/)[0]
    expr = str.gsub(/\/\d{4}$/,'').split(/-/).map!{|sstr| sstr = "#{sstr}/#{year}"}
    str = expr.join("-")
    str = fix_date_range(str)

  # any other single date (using the DateTime class to parse them)
  else
    str.gsub!(/,/,'') if /^#{@months}\s\d+,\s\d{4}$/.match(str)
    date = DateTime.strptime(str, '%m/%d/%Y') if /^\d+\/\d+\/\d{4}$/.match(str)
    date = DateTime.strptime(str, '%Y-%m-%d') if /^\d{4}-\d(\d)?-\d(\d)?$/.match(str)
    date = DateTime.strptime(str, '%m-%d-%Y') if /^\d(\d)?-\d(\d)?-\d{4}$/.match(str)
    date = DateTime.strptime(str, '%d %B %Y') if /^\d(\d)?\s#{@months}\s\d{4}$/.match(str)
    date = DateTime.strptime(str, '%B %d %Y') if /^#{@months}\s\d+\s\d{4}$/.match(str)
    str = date.strftime("%Y %B %-d") unless date.nil?
  end

  str = "#{pre} #{str}" unless pre.nil? # put the prefix back if we removed it
  str
rescue ArgumentError
  "Had some trouble parsing your date: #{str}"
end

# this does the cleanup for date ranges
def fix_date_range(str)
  if /^\w+\s/.match(str)
    unless /^#{@months}/.match(str)
      pre = str.scan(/\w+/)[0]
      str.gsub!(/^\w+\s/,'')
    end
  end

  expr = str.split(/-/).map!{|exp| fix_single_date(exp)}

  # de-duplication of dates within the range, e.g.:
  # * "2016 February 1-2016 February 14" becomes "2016 February 1-14"
  # * "2016 February 1-2016 March 31" becomes "2016 February 1-March 31"
  if expr[0][/^\d{4}/] == expr[1][/^\d{4}/]
    if expr[0][/^\d{4}\s#{@months}/] == expr[1][/^\d{4}\s#{@months}/]
      expr[1].gsub!(/^\d{4}\s\w+\s/,'')
    else
      expr[1].gsub!(/^\d{4}\s/,'')
    end
  end

  str = expr.join("-")
  str = "#{pre} #{str}" unless pre.nil?
  str
end

def set_date_codes(date, range)
  range.each {|k,v| date[k] = range[k] unless range[k] == date[k]}
  return date
end

ASTools::User.get_session

File.delete(log) if File.exist?(log)
f = File.open(log, 'a')

begin
  n = 0
  ids = ASTools::HTTP.get_json("/repositories/2/archival_objects", 'all_ids' => true)
  ids.each do |id|
    uri = "/repositories/2/archival_objects/#{id}"
    update = false
    json = ASTools::HTTP.get_json(uri)
    component_id = json['component_id']
    unless json['dates'].empty?
      json['dates'].each do |date|
        unless date['expression'].nil?
          unless is_dacs?(date['expression'])
            if undateds.include?(date['expression'])
              date = {}
              update = true
            else
              expr = cleanup(date['expression'])
              unless is_dacs?(expr)
                if /^#{@months}\s\d+(,\s\d{4})?-#{@months}\s\d+(,\s\d{4})?$/.match(expr)
                  expr = fix_date_range(expr)
                elsif /^(\w+\s)?\d+\/(\d+\/)?\d{4}-\d+\/(\d+\/)?\d{4}$/.match(expr)
                  expr = fix_date_range(expr)
                else
                  expr = fix_single_date(expr)
                end
              end
              date['expression'] = expr
              update = true
            end
          end
          unless date['expression'].nil? || date['expression'] == "various dates"
            range = set_range_dates(date['expression'])
            range.each do |k,v|
              if date[k] != range[k] || date[k].nil?
                date[k] = range[k]
                update = true
              end
            end
          end
        end
        f.puts "archival_object/#{id}: #{date.to_json}" if update
      end
    end
    if update
      resp = ASTools::HTTP.post_json(uri, json)
      if resp.is_a?(Net::HTTPSuccess) || resp.code == "200"
        n=n+1
      else
        error = JSON.parse(resp.body)['error']
        if error.is_a?(Hash)
          puts "Error: End date cannot precede the begin date: #{component_id}"
          f.puts "Error: End date cannot precede the begin date: #{component_id}"
        else
          puts "Error: #{error}: #{component_id}"
          f.puts "Error: #{error}: #{component_id}"
        end
      end
    end
  end
  puts "Finished. #{n} records updated."
ensure
  f.close
end
