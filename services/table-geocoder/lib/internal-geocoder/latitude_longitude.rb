# encoding: utf-8

require_relative '../../../importer/lib/importer/cartodb_id_query_batcher'
require_relative '../../../importer/lib/importer/query_batcher'

module CartoDB
  module InternalGeocoder

    class LatitudeLongitude

      def initialize(db, logger = nil)
        @db = db
        @logger = logger
      end

      def geocode(table_schema, table_name, latitude_column, longitude_column)
        qualified_table_name = "\"#{table_schema}\".\"#{table_name}\""
        query_fragment_update = %Q{
          UPDATE #{qualified_table_name}
          SET
            the_geom = ST_GeomFromText(
              'POINT(' || REPLACE(TRIM(CAST("#{longitude_column}" AS text)), ',', '.') || ' ' ||
                REPLACE(TRIM(CAST("#{latitude_column}" AS text)), ',', '.') || ')', #{CartoDB::SRID}
            )
        }
        # TODO: should we avoid overwriting the_geom?
        query_fragment_where = %Q{
          REPLACE(TRIM(CAST("#{longitude_column}" AS text)), ',', '.') ~
            '^(([-+]?(([0-9]|[1-9][0-9]|1[0-7][0-9])(\.[0-9]+)?))|[-+]?180)$'
          AND REPLACE(TRIM(CAST("#{latitude_column}" AS text)), ',', '.')  ~
            '^(([-+]?(([0-9]|[1-8][0-9])(\.[0-9]+)?))|[-+]?90)$'
        }

        if(table_has_cartodb_id(table_schema, table_name))
          CartoDB::Importer2::CartodbIdQueryBatcher.new(@db, @logger).execute(
              %Q{#{query_fragment_update} where #{query_fragment_where}},
              qualified_table_name
          )
        else
        CartoDB::Importer2::QueryBatcher::execute(
          @db,
          %Q{
            #{query_fragment_update} 
            #{CartoDB::Importer2::QueryBatcher::QUERY_WHERE_PLACEHOLDER}
            where #{query_fragment_where} 
            #{CartoDB::Importer2::QueryBatcher::QUERY_LIMIT_SUBQUERY_PLACEHOLDER}
          },
          qualified_table_name,
          @logger,
          'Populating the_geom from latitude / longitude'
        )
        end
      end

      def table_has_cartodb_id(table_schema, table_name)
        result = @db.fetch(%Q{
          select *
          from information_schema.columns
          where table_schema = '#{table_schema}' 
            and table_name = '#{table_name}' 
            and column_name = 'cartodb_id';
        }).all
        !result[0].nil?
      end

    end

  end
end
