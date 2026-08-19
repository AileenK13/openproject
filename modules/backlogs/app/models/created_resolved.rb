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

class CreatedResolved
  def initialize(sprint, project, _burn_direction = nil)
    @sprint_id = sprint.id

    make_date_series sprint

    #series_data = OpenProject::Backlogs::CreatedResolved::SeriesRawData.new(project,
    #                                                                 sprint,
    #                                                                 points: ["story_points"])

    series_data = OpenProject::Backlogs::CreatedResolved::SeriesRawData.new(project,
                                                                     sprint,
                                                                     workpackages: ["wp_created", "wp_resolved"])

    series_data.collect_data

    #series_data =
    #{"created" => {Fri, 31 Jul 2026 => 0.0, Mon, 03 Aug 2026 => 0.0, Tue, 04 Aug 2026 => 0.0}, "resolved" => {Fri, 31 Jul 2026 => 0.0, Mon, 03 Aug 2026 => 0.0, Tue, 04 Aug 2026 => 0.0}}

    calculate_series series_data
    
    result = calculate_series series_data
    Rails.logger.info ">>> DEBUG result = #{result.inspect}"

    determine_max
  end

  #attr_reader :days, :sprint_id, :max, :story_points, :story_points_ideal
  attr_reader :days, :sprint_id, :max, :created, :resolved

  def series(_select = :active)
    @available_series
  end

  private

  def make_date_series(sprint)
    @days = if sprint.start_date && sprint.finish_date
              Day.working.from_range(from: sprint.start_date, to: sprint.finish_date).map(&:date)
            else
              []
            end
  end

  def calculate_series(series_data)
    Rails.logger.info ">>> DEBUG: series:data -> #{series_data.inspect}"
    #hier steht erst mal nur "story_points drinnen"
    #collect_names = ["created", "resolved"]
    series_data.collect_names.each do |c|
      # need to differentiate between hours and sp
      Rails.logger.info ">>> DEBUG c = #{c}"
      make_series c.to_sym, series_data.unit_for(c), series_data[c].to_a.sort_by(&:first).map(&:last)
    end

    #calculate_ideals(series_data)
    #calculate_resolved(series_data)
  end

  #brauche ich wahrscheinlich nicht, da es keine "ideal"-Reihe gibt
  #def calculate_ideals(data)
  #def calculate_resolved
  #  #(["story_points"] & data.collect_names).each do |ideal|
  #  (["created"] & data.collect_names).each do |ideal|
  #    #ideal = "story_points"
  #    calculate_ideal(ideal, data.unit_for(ideal))
  #  end
  #end

  #brauche ich wahrscheinlich nicht, da es keine "ideal"-Reihe gibt
  def calculate_ideal(name, unit)
    max = send(name).first || 0.0
    delta = max / (days.size - 1)

    ideal = []
    days.each_with_index do |_d, i|
      ideal[i] = max - (delta * i)
    end

    #make_series "#{name}_ideal", unit, ideal
    make_series "resolved", unit, ideal
  end

  def make_series(name, units, data)
    @available_series ||= {}
    s = OpenProject::Backlogs::CreatedResolved::Series.new(data, name, units)
    #Rails.logger.info ">>> DEBUG s = #{s.inspect}"
    #s = [0.0, 0.0, 0.0]
    @available_series[name] = s
    instance_variable_set(:"@#{name}", s)
  end

  def determine_max
    @max = {
      #points: @available_series.values.select { |s| s.unit == :points }.flatten.compact.reject(&:nan?).max || 0.0,
      workpackages: @available_series.values.select { |s| s.unit == :workpackages }.flatten.compact.reject(&:nan?).max || 0.0,
      hours: @available_series.values.select { |s| s.unit == :hours }.flatten.compact.reject(&:nan?).max || 0.0
    }
  end
end
