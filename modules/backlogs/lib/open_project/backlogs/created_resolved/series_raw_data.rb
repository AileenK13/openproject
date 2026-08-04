# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module OpenProject::Backlogs::CreatedResolved
  class SeriesRawData < Hash
    def initialize(*args)
      @collect = args.pop
      @sprint = args.pop
      @project = args.pop
      super
    end

    attr_reader :collect, :sprint, :project

    def collect_names
      #@collect_names = ["created", "resolved"]
      @collect_names ||= @collect.to_a.map(&:last).flatten
      #Rails.logger.info ">>> DEBUG collect_names -> #{@collect_names}"
    end

    def unit_for(name)
      # :points if @collect[:points].include? name
      :workpackages if @collect[:workpackages].include? name
      #Rails.logger.info ">>> DEBUG :points -> #{:workpackages}"
    end

    def collect_data
      initialize_self_for_collection
      #Rails.logger.info ">>> DEBUG data_for_dates 2 -> #{data_for_dates.inspect}"
      data_for_dates.each do |day_data| 
        #day_data burndown = {"date" => Fri, 31 Jul 2026, "story_points" => 0.5e1}
        date = day_data["date"]
        date = Date.parse(date) unless date.is_a?(Date)
        #date = 2026-07-31
       
        Rails.logger.info ">>> DEBUG day_data2 -> #{day_data.inspect}"
        #day_data = {"date" => Fri, 31 Jul 2026, "story_points" => 0.5e1}
        day_data.each do |key, value|
          next if key == "date"

          #Rails.logger.info ">>> DEBUG dd key: #{key.inspect}"
          #Rails.logger.info ">>> DEBUG dd value: #{value.inspect}"
          Rails.logger.info ">>> DEBUG self: #{self.inspect}"
          #self[story_points][2026-07-31] = 5.0
          #self = {"created" => {Fri, 31 Jul 2026 => 0.0}, "resolved" => {Fri, 31 Jul 2026 => 0.0}}
          #self.each do |entry|
            #Rails.logger.info ">>> DEBUG value: #{value}"
            #self[key][date] = value.to_f
          #end
          self.transform_values do |entry|
            self[key][date] = value.to_f
          end
          #self[key][date] = value.to_f
        end
      end
    end

    private

    def initialize_self_for_collection
      date_hash = {}

      collected_days.each do |date|
        date_hash[date] = 0.0
      end

      #collect_names = ["created", "resolved"]
      collect_names.each do |c|
        self[c] = date_hash.dup
      end
      #self = {"created" => {Fri, 31 Jul 2026 => 0.0}, "resolved" => {Fri, 31 Jul 2026 => 0.0}}
    end

    def collected_days
      @collected_days ||= day_query.where(date: ..Time.zone.today).order(:date).map(&:date)
    end

    def data_for_dates

      query_string = <<~SQL.squish
        SELECT
          days.date,
          /*COUNT() as work_packages*/
          /*COALESCE(SUM(work_package_journals.story_points), 0.0) AS wp_created,*/
          COUNT(*) FILTER (WHERE date_trunc('day', work_packages.created_at) = days.date) AS wp_created,
          COUNT(*) FILTER (WHERE work_package_journals.status_id IN (12,14)) AS wp_resolved
        FROM
          work_package_journals
        LEFT JOIN
          journals
        ON work_package_journals.id = journals.data_id
          AND journals.data_type = '#{Journal::WorkPackageJournal.name}'
          AND #{container_query}
          AND #{project_id_query}
          #{and_status_query}
        LEFT JOIN 
          work_packages 
        ON journals.journable_id = work_packages.id
        JOIN
          (#{day_query.to_sql}) days
        ON (days.date::timestamp + interval '23:59:59') AT TIME ZONE '#{User.current.time_zone.tzinfo.name}' <@ journals.validity_period
        GROUP BY days.date
        ORDER BY days.date
      SQL

=begin
      query_string = <<~SQL.squish
        SELECT
          days.date,
          COALESCE(SUM(work_package_journals.story_points), 0.0) as story_points
        FROM
          work_package_journals
        LEFT JOIN
          journals
        ON work_package_journals.id = journals.data_id
          AND journals.data_type = '#{Journal::WorkPackageJournal.name}'
          AND #{container_query}
          AND #{project_id_query}
          #{and_status_query}
        JOIN
          (#{day_query.to_sql}) days
        ON (days.date::timestamp + interval '23:59:59') AT TIME ZONE '#{User.current.time_zone.tzinfo.name}' <@ journals.validity_period
        GROUP BY days.date
        ORDER BY days.date
      SQL
=end
      Rails.logger.info ">>> DEBUG query_string: #{query_string}"
      Journal::WorkPackageJournal.connection.select_all query_string
    end

    def and_status_query
      non_closed_statuses = Status.where(is_closed: false).pluck(:id)

      done_statuses_for_project = project.done_statuses.pluck(:id)

      open_status_ids = non_closed_statuses + done_statuses_for_project

      if open_status_ids.empty?
        # No work packages count as remaining, so force the LEFT JOIN to
        # produce no matches, making the SUM evaluate to 0 (via COALESCE).
        "AND 1=0"
      else
        "AND (#{Journal::WorkPackageJournal.table_name}.status_id IN (#{open_status_ids.join(',')}))"
      end
    end

=begin
    def and_status_query
      non_closed_statuses = Status.where(is_closed: false).pluck(:id)

      done_statuses_for_project = project.done_statuses.pluck(:id)

      open_status_ids = non_closed_statuses - done_statuses_for_project

      if open_status_ids.empty?
        # No work packages count as remaining, so force the LEFT JOIN to
        # produce no matches, making the SUM evaluate to 0 (via COALESCE).
        "AND 1=0"
      else
        "AND (#{Journal::WorkPackageJournal.table_name}.status_id IN (#{open_status_ids.join(',')}))"
      end
    end
=end

    def container_query
      "(#{Journal::WorkPackageJournal.table_name}.sprint_id = #{sprint.id})"
    end

    def project_id_query
      "(#{Journal::WorkPackageJournal.table_name}.project_id = #{project.id})"
    end

    def day_query
      lower_bound = sprint.start_date
      upper_date = sprint.finish_date
      upper_bound = Time.zone.today.clamp(lower_bound, upper_date)

      return Day.none unless upper_bound && lower_bound

      Day.working.from_range(from: lower_bound, to: upper_bound)
    end
  end
end
