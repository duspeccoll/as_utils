#!/usr/bin/env ruby

# this is eventually going to be an ArchivesSpace date cleanup script, but right
# now it just writes a list of the dates it *would* be fixing to stdout

require 'date'
require_relative 'astools'

# this is why no one should write a DACS 2.4 validator for dates
@months = /(January|February|March|April|May|June|July|August|September|October|November|December)/
@dacs_date = /^((((((before|after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)(-\d+(st|nd|th))?\scentury)))|(\d{4}(\s#{@months}(\s\d+(-\d+)?)?)?)))|((((between|circa|before)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)\scentury)))|(\d{4}(\s#{@months}(\s\d+)?)?))-((after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)\scentury)))|(\d{4}(\s#{@months}(\s\d+)?)?)))|(((between|circa|before)\s)?\d{4}\s#{@months}(\s\d+)?-((after|circa)\s)?#{@months}(\s\d+)?)|(((between|circa)\s)?\d{4}\s#{@months}\s\d+-\d+)))((,|\sor)\s((((before|after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?\d{4}s)|(\d{4}(\s#{@months}(\s\d+)?)?)))|(((between|circa|before)\s)?((\d{4}(s|(\s#{@months}(\s\d+)?))?-(after)?\d{4}(s|(\s#{@months}(\s\d+)?))?)|(\d{4}\s#{@months}(\s\d+)?-#{@months}(\s\d+)?)|(\d{4}\s#{@months}\s\d+-\d+)))))?( and undated)?)|various dates)$/

# here are some hashes and arrays for cleanup tasks
@downcases = ["circa", "before", "after", "between", "early", "mid", "late"]
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
  str.gsub!(/\s(-|to|and(?! undated))\s/,"-")
  str = str.gsub(/\s?-\s?/,"-").gsub(/-and\s/,"-").gsub(/(;\s|\s,\s)/,", ").gsub(/\s\s+?/," ").gsub(/'s/,"s").gsub(/^(\s+?|FY\s)/,"").gsub(/\s&\s/,", ")
  str.gsub!(/^c{1}(a|\.)(\.|\s)?\s?/,"circa ")
  str.gsub!(/,/,", ") if /,\d/.match(str)

  # downcase and spell check
  @downcases.each {|dstr| str.gsub!(/#{dstr.capitalize}/,"#{dstr}")}
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

# this does the cleanup for single dates
def fix_single_date(str)
  str = str.gsub(/\/0\//,'')
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

ASTools::User.get_session

File.delete(log) if File.exist?(log)
f = File.open(log, 'a')

begin
  ids = ASTools::HTTP.get_json("/repositories/2/archival_objects", 'all_ids' => true)
  ids.each {|id|
    json = ASTools::HTTP.get_json("/repositories/2/archival_objects/#{id}")
    component_id = json['component_id']
    json['dates'].each {|date|
      unless date['expression'].nil?
        if is_dacs?(date['expression'])
          f.puts "#{component_id}: #{date['expression']} already DACS-compliant"
        else
          if undateds.include?(date['expression'])
            f.puts "#{component_id}: #{date['expression']} classified as 'undated,' removing"
          else
            old_expr = date['expression']
            expr = cleanup(old_expr) # clean up punctuation and spelling mistakes

            if is_dacs?(expr) # if the date is already valid per DACS 2.4, don't do anything else with it
              f.puts "#{component_id}: #{old_expr} => #{expr} [is DACS]"
            else
              # if there's a dash in the date expression we check if it's a date range or not
              if /^#{@months}\s\d+(,\s\d{4})?-#{@months}\s\d+(,\s\d{4})?$/.match(expr)
                expr = fix_date_range(expr)
              elsif /^(\w+\s)?\d+\/(\d+\/)?\d{4}-\d+\/(\d+\/)?\d{4}$/.match(expr)
                expr = fix_date_range(expr)
              #elsif /^(\w+\s)?\d+\/\d{4}-\d+\/\d{4}$/.match(expr)
              #  expr = fix_date_range(expr)
              else
                expr = fix_single_date(expr)
              end

              # finish up
              if is_dacs?(expr)
                f.puts "#{component_id}: #{old_expr} => #{expr} [is DACS]"
              else
                if expr.start_with?("Had some trouble")
                  f.puts "#{component_id}: #{expr}"
                else
                  f.puts "#{component_id}: #{old_expr} => #{expr} [is NOT DACS]"
                end
              end
            end
          end
        end
      end
    } unless json['dates'].empty?
  }
ensure
  f.close
end
