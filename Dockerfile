ARG         version=latest
ARG         base=apache/superset:${version}

###

FROM        ${base}

USER        root

RUN         pip install -v \
                mysqlclient \
                sqlalchemy-redshift \
                sqlalchemy-databricks \
                pybigquery \
                clickhouse-driver==0.2.0 \
                clickhouse-sqlalchemy==0.1.6 \
                databricks-sql-connector \

USER        superset
