\# oracle-db-cicd-demo



Oracle Database CI/CD demo using:



\- Git as source of truth

\- Jenkins

\- Docker image with SQLcl + Liquibase

\- Oracle Database Free

\- Liquibase changelog tracking

\- SQLcl validation and smoke tests



\## Structure



\- `changelog/controller.xml` is the master Liquibase changelog.

\- `changelog/versioned/` contains one-time changes.

\- `changelog/repeatable/` contains repeatable PL/SQL object changes.

\- `objects/` contains SQL and PL/SQL source files.

\- `validation/` contains post-deployment validation scripts.



\## Rule



The database is not the source of truth. Git is the source of truth.

