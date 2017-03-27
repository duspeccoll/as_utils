#!/usr/bin/env ruby

# this is eventually going to be an ArchivesSpace date cleanup script, but right
# now it just writes a list of the dates it *would* be fixing to stdout

require 'date'
require_relative 'astools'

# this is why no one should write a DACS 2.4 validator for dates
@months = /(January|February|March|April|May|June|July|August|September|October|November|December)/
@dacs_date = /^((((before|after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)(-\d+(st|nd|th))?\scentury)))|(\d{4}(\s#{@months}(\s\d+)?)?)))|((((between|circa|before)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)\scentury)))|(\d{4}(\s#{@months}(\s\d+)?)?))-(after)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?((\d{4}s)|(\d+(st|nd|th)\scentury)))|(\d{4}(\s#{@months}(\s\d+)?)?)))|(((between|circa|before)\s)?\d{4}\s#{@months}(\s\d+)?-(after)?#{@months}(\s\d+)?)|(((between|circa)\s)?\d{4}\s#{@months}\s\d+-\d+)))((,| or)\s((((before|after|circa)\s)?(((((early|mid|late|early-mid|mid-late)\s)|mid-)?\d{4}s)|(\d{4}(\s#{@months}(\s\d+)?)?)))|(((between|circa|before)\s)?((\d{4}(s|(\s#{@months}(\s\d+)?))?-(after)?\d{4}(s|(\s#{@months}(\s\d+)?))?)|(\d{4}\s#{@months}(\s\d+)?-#{@months}(\s\d+)?)|(\d{4}\s#{@months}\s\d+-\d+)))))?( and undated)?$/

# here are some hashes and arrays for cleanup tasks
@downcases = ["circa", "before", "after", "between", "early", "mid", "late"]
undateds = ["Date Not Yet Determined", "UNKNOWN", "Unknown", "unknown", "N/A", "n.d.", "no date", "Undated", "undated"]
mos = {
  /Jan(\.|\s)/ => "January",
  /Feb(\.|\s)/ => "February",
  /Mar(\.|\s)/ => "March",
  /Apr(\.|\s)/ => "April",
  /Aug(\.|\s)/ => "August",
  /Sept(\.|\s)/ => "September",
  /Oct(\.|\s)/ => "October",
  /Nov(\.|\s)/ => "November",
  /Dec(\.|\s)/ => "December"
}

# check if a date validates against that monstrous DACS validation regexp
def is_dacs?(str)
  return true if @dacs_date.match(str)
  false
end

# all our pre-processing clean-up tasks
def cleanup(str)
  str.strip!
  str.gsub!(/\s(-|to|and(?! undated))\s/,"-")
  str = str.gsub(/\s?-\s?/,"-").gsub(/-and\s/,"-").gsub(/(;\s|\s,\s)/,", ").gsub(/\s\s+?/," ").gsub(/'s/,"s").gsub(/^(\s+?|FY\s)/,"").gsub(/\s&\s/,", ")
  str.gsub!(/^c{1}(a|\.)(\.|\s)?\s?/,"circa ")
  str.gsub!(/,/,", ") if /,\d/.match(str)
  str = "circa #{str.gsub(/circa /,'')}" if /^\d+-circa\s\d+$/.match(str)

  # downcase and spell check
  @downcases.each {|dstr| str.gsub!(/#{dstr.capitalize}/,"#{dstr}")}
  str.gsub!(/(betwen|betweem|beetween|betweeen)/,"between")
  str.gsub!(/between/,"between ") if /between\d/.match(str)
  str.gsub!(/, (U|u)ndated/, " and undated") if /, (U|u)ndated$/.match(str)

  # insert or modify date range prefixes (before, after, circa)
  str = "after #{str.gsub(/-/,'')}" if str.end_with?("-")
  str = "after #{str.gsub(/-Present/,'')}" if str.end_with?("-Present")
  str = "after #{str.gsub(/-Unknown/, '')}" if str.end_with?("-Unknown")
  str = "before #{str.gsub(/-/,'')}" if str.start_with?("-")
  str = "circa #{str.gsub(/\?/,'')}" if str.end_with?("?")
  str.gsub!(/^Around/,"circa") if str.start_with?("Around")
  str.gsub!(/-circa\s/,"-") if str.start_with?("circa")

  str
end

# this does the cleanup for M/D/Y dates; the script refers back to it a lot
def fix_slash_dates(str)
  str.gsub!(/\/0\//,'/')
  pre = str.scan(/\w+/)[0] if /^\w+\s/.match(str)
  str.gsub!(/^\w+\s/,'')
  unless /^\d{4}$/.match(str)
    if /^\d+\/\d+$/.match(str)
      str = DateTime.strptime(str, '%m/%Y').strftime("%Y %B")
    else
      if /^\d(\d)?\/\d{4}-\d(\d)?\/\d{4}/.match(str)
        expr = str.split(/-/).map!{|exp| DateTime.strptime(exp, '%m/%Y').strftime("%Y %B")}
        str = expr.join("-")
      elsif /^\d+\/\d+-\d+\/\d{4}$/.match(str)
        expr = str.split(/\//)
        str = "#{expr[2]} #{DateTime.strptime(expr[0], '%m').strftime("%B")} #{expr[1].gsub(/0(\d{1})/,'\1')}"
      else
        str = DateTime.strptime(str, '%m/%d/%Y').strftime("%Y %B %-d")
      end
    end
  end
  str = "#{pre} #{str}" unless pre.nil?

  str
rescue ArgumentError
  "Had some trouble parsing your date: #{str}"
end

# this does the cleanup for any other kind of date, if the DateTime class is able to do it
def fix_other_dates(str)
  case
  when /^#{@months}\s\d+\s\d{4}$/.match(str)
    date = DateTime.strptime(str, '%B %d %Y')
    return date.strftime("%Y %B %-d")
  when /^#{@months}\s\d{4}$/.match(str)
    date = DateTime.strptime(str, '%B %Y')
    return date.strftime("%Y %B")
  when /^#{@months}\s\d+,\s\d{4}$/.match(str)
    date = DateTime.strptime(str, '%B %d, %Y')
    return date.strftime("%Y %B %-d")
  end

rescue ArgumentError
  "Had some trouble parsing your date: #{str}"
end

ASTools::User.get_session

File.delete('log.txt') if File.exist?('log.txt')
f = File.open('log.txt', 'a')

ids = ASTools::HTTP.get_json("/repositories/2/archival_objects", 'all_ids' => true)
ids.each {|id|
  json = ASTools::HTTP.get_json("/repositories/2/archival_objects/#{id}")
  component_id = json['component_id']
  unless json['dates'].empty?
    json['dates'].each {|date|
      unless date['expression'].nil?
        unless is_dacs?(date['expression'])
          if undateds.include?(date['expression'])
            f.puts "#{component_id}: #{date['expression']} classified as 'undated,' removing"
          else
            expression = date['expression']
            old_expression = expression

            # clean up oddball punctuation and abbreviations
            expression = cleanup(expression)

            # if the date is already valid per DACS 2.4, don't try to edit it
            if is_dacs?(expression)
              f.puts "#{component_id}: #{old_expression} => #{expression} [is DACS]"
            else
              # we allow the DateTime class to clean up what it can
              expression = Date.parse(expression).strftime("%Y %B %-d") if /^\d{4}-\d{2}-\d{2}$/.match(expression)
              expression = DateTime.strptime(expression, '%d %B %Y').strftime("%Y %B %-d") if /^\d(\d)?\s#{@months}\s\d{4}/.match(expression)
              if /^#{@months}\s\d(\d)?,?\s\d{4}$/.match(expression)
                expression.gsub!(/,/,'')
                expression = fix_other_dates(expression)
              end

              # convert basic M Y dates to put the year in front
              if /^#{@months}(-#{@months})?(,)?\s\d{4}$/.match(expression)
                expression.gsub!(/,/,'')
                year = expression.scan(/\d{4}/)[0]
                expression = "#{year} #{expression.gsub!(/\s\d{4}$/,"")}"
              end

              # convert Month Year ranges
              if /^#{@months}\s\d{4}-#{@months}\s\d{4}$/.match(expression)
                expr = expression.split(/-/).map!{|exp| exp = fix_other_dates(exp)}
                expression = expr.join("-")
              end

              # convert slash dates

              # * this is to fix academic year slash-or-dash dates (e.g. 1987/88, 1987-88)
              if /^(\w+\s)?\d{4}(\/|-)\d{2}$/.match(expression)
                if /^\w+\s/.match(expression)
                  pre = expression.scan(/\w+/)[0]
                  expression.gsub!(/^\w+\s/,"")
                end
                expression = "#{expression[0,4]}-#{expression[0,2]}#{expression[5,2]}"
                expression = "#{pre} #{expression}" unless pre.nil?
              end

              # * this is to fix single slash dates
              if /^(\w+\s)?\d+\/\d+(\/\d+)?$/.match(expression)
                expression = fix_slash_dates(expression)
              end

              # * this is to fix slash dates in a range
              if /^(\w+\s)?\d+\/\d+(\/\d+)?-\d+\/\d+(\/\d+)?$/.match(expression)
                if /^(\w+\s)?\d{2}\/\d+-\d+\/\d{4}$/.match(expression)
                  expression = fix_slash_dates(expression)
                else
                  expr = expression.split(/-/).map!{|exp| exp = fix_slash_dates(exp)}
                  if expr[0][/^\d{4}/] == expr[1][/^\d{4}/]
                    if expr[0][/^\d{4}\s#{@months}/] == expr[1][/^\d{4}\s#{@months}/]
                      expr[1].gsub!(/^\d{4}\s\w+\s/,'')
                    else
                      expr[1].gsub!(/^\d{4}\s/,'')
                    end
                  end
                  expression = expr.join("-")
                end
              end

              # * this is to fix slash dates if they're preceded by a time modifier (e.g. before, after)
              if /^\w+\s\d+\/\d+\/\d+/.match(expression)
                pre = expression.scan(/\w+/)[0]
                expression.gsub!(/^\w+\s/,"")
                if /^\d+\/\d+\/\d+$/.match(expression)
                  expression = fix_slash_dates(expression)
                elsif /^\d+\/\d+\/\d+-\d+\/\d+\/\d+$/.match(expression)
                  expr = expression.split(/-/).map!{|exp| fix_slash_dates(exp)}
                  if expr[0][/^\d{4}/] == expr[1][/^\d{4}/]
                    if expr[0][/^\d{4}\s#{@months}/] == expr[1][/^\d{4}\s#{@months}/]
                      expr[1].gsub!(/^\d{4}\s\w+\s/,'')
                    else
                      expr[1].gsub!(/^\d{4}\s/,'')
                    end
                  end
                  expression = expr.join("-")
                end
                expression = "#{pre} #{expression}" unless pre.nil?
              end

              # * this is to fix 'M D, Y'-formatted dates
              if /^\w+(\.)?\s\d+(-\d+)?,\s\d+/.match(expression)
                # spell out month abbreviations
                mos.each {|k,v| expression.gsub!(k,v) if /^#{k}/.match(expression)}

                # just do the fix in one line if it's a single M D, Y date
                if /^#{@months}\s\d+,\s\d+$/.match(expression)
                  expression = fix_other_dates(expression)

                # if it's a range we need to split it into two dates and fix each separately
                elsif /^#{@months}\s\d+,\s\d+-#{@months}\s\d+,\s\d+$/.match(expression)
                  exps = expression.split(/-/).map!{|exp| exp = fix_other_dates(expression)}
                  expression = exps.join("-")

                # if it's a range within a single month we have to separate out its component parts and rebuild it
                elsif /^#{@months}\s\d+-\d+,\s\d+$/.match(expression)
                  month = expression.scan(/\w+/)[0]
                  date = expression.scan(/\d+-\d+/)[0]
                  expression.gsub!(/^\w+\s\d+-\d+,\s/,"")
                  expression = "#{expression} #{month} #{date}"

                # any other case we ignore due to High Weirdness
                else
                  nil
                end
              end

              # finish up
              if is_dacs?(expression)
                f.puts "#{component_id}: #{old_expression} => #{expression} [is DACS]"
              else
                if expression.start_with?("Had some trouble")
                  f.puts "#{component_id}: #{expression}"
                else
                  f.puts "#{component_id}: #{old_expression} => #{expression} [is NOT DACS]"
                end
              end
            end
          end
        end
      end
    }
  end
}

f.close unless f.nil?
