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
# ++

module Backlogs
  module SprintReports
    module Widgets
      class CreatedResolvedChart < Grids::WidgetComponent
        param :sprint
        param :project

        #Ist der Titel des Widgets
        # t() = translate () -> zieht sich Text aus /home/coche/dev/openproject/modules/backlogs/config/locales/en.yml
        # wird in ??? benutzt
        def title
          t("backlogs.show_created_resolved_chart")
        end

        #
        #
        #
        def chart_data
          {
            labels: xaxis_labels(createdResolved),
            datasets: dataseries(createdResolved)
          }.to_json
        end

        def wrapper_arguments
          { full_width: true }
        end

        private

        def createdResolved
          return nil unless sprint.date_range_set?

          #@burndown ||= Burndown.new(sprint, project)
          @createdResolved ||= CreatedResolved.new(sprint, project)
        end

        def xaxis_labels(createdResolved)
          # 14 entries (plus the axis label) have come along as the best value for a good optical result.
          # Thus it is enough space between the entries.
          entries_displayed = (createdResolved.days.length / 14.0).ceil
          createdResolved.days.enum_for(:each_with_index).map do |d, i|
            if (i % entries_displayed) == 0
              ["#{::I18n.t('date.abbr_day_names')[d.wday % 7]} #{d.strftime('%d/%m')}"]
            end
          end
        end

        def dataseries(createdResolved)
          createdResolved.series.map do |s|
            {
              label: I18n.t("createdResolved.#{s.first}"),
              data: s.last.enum_for(:each)
            }
          end
        end
      end
    end
  end
end
