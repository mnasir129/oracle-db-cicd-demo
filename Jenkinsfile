def nexusRegistry = "192.168.0.121:8081"
def oracleSqlclImage = "${nexusRegistry}/docker-hosted/local-oracle-sqlcl-liquibase:latest"

pipeline {
    agent { label 'linux-docker' }

    options {
        ansiColor('xterm')
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(name: 'RUN_DB_CI', defaultValue: true, description: 'Run Oracle DB CI validation and preview')
        booleanParam(name: 'RUN_DB_DEPLOY', defaultValue: false, description: 'Apply Liquibase update to Oracle CI schema')
    }

    stages {
        stage('Oracle DB CI/CD') {
            when {
                expression { return params.RUN_DB_CI }
            }

            agent {
                docker {
                    image "${oracleSqlclImage}"
                    registryUrl "http://${nexusRegistry}"
                    registryCredentialsId 'nexus-creds'
                    reuseNode true
                    alwaysPull true
                    label 'linux-docker'

                    /*
                     * Run container as Jenkins user to avoid root-owned workspace files.
                     * Current Jenkins UID/GID: 972:969
                     */
                    args '-u 972:969 -e HOME=/tmp'
                }
            }

            stages {
                stage('Checkout DB Repo') {
                    steps {
                        checkout scm

                        sh '''
                            set -e

                            echo "Current workspace:"
                            pwd

                            echo "Repository files:"
                            find . -type f | sort

                            mkdir -p logs artifacts
                        '''
                    }
                }

                stage('Validate Repo Structure') {
                    steps {
                        sh '''
                            set -e

                            echo "Validating required files..."

                            test -f changelog/controller.xml
                            test -f changelog/versioned/V001_create_demo_table.xml
                            test -f changelog/repeatable/R001_demo_pkg_spec.xml
                            test -f changelog/repeatable/R002_demo_pkg_body.xml

                            test -f objects/tables/create_demo_table.sql
                            test -f objects/packages/demo_pkg_spec.sql
                            test -f objects/packages/demo_pkg_body.sql

                            test -f validation/db_health_check.sql
                            test -f validation/check_invalid_objects.sql
                            test -f validation/smoke_test.sql

                            echo "Repo structure validation passed." | tee logs/repo-structure-validation.log
                        '''
                    }
                }

                stage('Show SQLcl Version') {
                    steps {
                        sh '''
                            set -e

                            sql -V | tee logs/sqlcl-version.log
                            java -version 2>&1 | tee logs/java-version.log
                            zip -v | head -3 | tee logs/zip-version.log
                        '''
                    }
                }

                stage('DB Connection Test') {
                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Testing Oracle DB connection..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" @validation/db_health_check.sql > logs/db-health-check.log

                                echo "DB health check output:"
                                cat logs/db-health-check.log
                            '''
                        }
                    }
                }

                stage('Liquibase Validate') {
                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Running Liquibase validate..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > logs/liquibase-validate.log
liquibase validate -changelog-file changelog/controller.xml
exit
SQL

                                echo "Liquibase validate output:"
                                cat logs/liquibase-validate.log
                            '''
                        }
                    }
                }

                stage('Liquibase Status') {
                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Running Liquibase status..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > logs/liquibase-status.log
liquibase status -changelog-file changelog/controller.xml
exit
SQL

                                echo "Liquibase status output:"
                                cat logs/liquibase-status.log
                            '''
                        }
                    }
                }

                stage('Generate Deployment Preview SQL') {
                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Generating deployment-preview.sql using Liquibase update-sql..."

                                rm -f deployment-preview.sql

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > deployment-preview.sql
liquibase update-sql -changelog-file changelog/controller.xml
exit
SQL

                                cp deployment-preview.sql logs/deployment-preview.sql

                                echo "Preview SQL generated:"
                                ls -lh deployment-preview.sql

                                echo "First 80 lines of deployment-preview.sql:"
                                head -80 deployment-preview.sql || true
                            '''
                        }
                    }
                }

                stage('Liquibase Update Deploy') {
                    when {
                        expression { return params.RUN_DB_DEPLOY }
                    }

                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Running Liquibase update. This applies Git-controlled DB changes to the CI schema..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > logs/liquibase-update.log
liquibase update -changelog-file changelog/controller.xml
exit
SQL

                                echo "Liquibase update output:"
                                cat logs/liquibase-update.log
                            '''
                        }
                    }
                }

                stage('Check Invalid Objects') {
                    when {
                        expression { return params.RUN_DB_DEPLOY }
                    }

                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Checking invalid database objects after deployment..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" @validation/check_invalid_objects.sql > logs/check-invalid-objects.log

                                echo "Invalid object check output:"
                                cat logs/check-invalid-objects.log
                            '''
                        }
                    }
                }

                stage('Run Smoke Test') {
                    when {
                        expression { return params.RUN_DB_DEPLOY }
                    }

                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Running smoke test..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" @validation/smoke_test.sql > logs/smoke-test.log

                                echo "Smoke test output:"
                                cat logs/smoke-test.log
                            '''
                        }
                    }
                }

                stage('Check Liquibase History') {
                    when {
                        expression { return params.RUN_DB_DEPLOY }
                    }

                    steps {
                        withCredentials([
                            usernamePassword(
                                credentialsId: 'oracle-ci-creds',
                                usernameVariable: 'ORACLE_USER',
                                passwordVariable: 'ORACLE_PASSWORD'
                            ),
                            string(
                                credentialsId: 'oracle-ci-connect-string',
                                variable: 'ORACLE_CONNECT_STRING'
                            )
                        ]) {
                            sh '''
                                set +x
                                set -e

                                echo "Checking Liquibase DATABASECHANGELOG history..."

                                cat > check_liquibase_history.sql <<'SQL'
SET LINESIZE 250
COLUMN id FORMAT A35
COLUMN author FORMAT A15
COLUMN filename FORMAT A60
COLUMN dateexecuted FORMAT A35

SELECT id, author, filename, dateexecuted
FROM databasechangelog
ORDER BY dateexecuted;

EXIT
SQL

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" @check_liquibase_history.sql > logs/liquibase-history.log

                                echo "Liquibase history output:"
                                cat logs/liquibase-history.log
                            '''
                        }
                    }
                }

                stage('Package DB Release Files') {
                    steps {
                        sh '''
                            set -e

                            RELEASE_ZIP="oracle-db-cicd-demo-${BUILD_NUMBER}.zip"

                            echo "Creating release ZIP: ${RELEASE_ZIP}"

                            zip -r "${RELEASE_ZIP}" \
                                changelog \
                                objects \
                                validation \
                                logs \
                                README.md \
                                .gitignore \
                                Jenkinsfile \
                                deployment-preview.sql

                            cp "${RELEASE_ZIP}" artifacts/

                            echo "Release ZIP created:"
                            ls -lh "${RELEASE_ZIP}"
                            ls -lh artifacts/
                        '''
                    }
                }

                stage('Archive Pipeline Artifacts') {
                    steps {
                        archiveArtifacts artifacts: '''
                            deployment-preview.sql,
                            logs/*.log,
                            logs/*.sql,
                            artifacts/*.zip
                        ''', fingerprint: true
                    }
                }
            }

            post {
                always {
                    echo "Cleaning Oracle DB CI/CD workspace"
                    deleteDir()
                }
            }
        }
    }

    post {
        always {
            echo "Oracle DB CI/CD pipeline finished"
            deleteDir()
        }

        failure {
            echo "Oracle DB CI/CD pipeline failed. Check DB connection, Liquibase changelog, SQLcl logs, invalid objects, or smoke test output."
        }

        success {
            echo "Oracle DB CI/CD pipeline completed successfully."
        }
    }
}