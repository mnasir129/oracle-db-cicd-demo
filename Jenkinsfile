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
    }

    stages {
        stage('Oracle DB CI Validation') {
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
                            echo "Current workspace:"
                            pwd

                            echo "Repository files:"
                            find . -type f | sort
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

                            echo "Repo structure validation passed."
                        '''
                    }
                }

                stage('Show SQLcl Version') {
                    steps {
                        sh '''
                            sql -V
                            java -version
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
                                echo "Testing Oracle DB connection..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" @validation/db_health_check.sql > db-health-check.log

                                echo "DB health check output:"
                                cat db-health-check.log
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
                                echo "Running Liquibase validate..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > liquibase-validate.log
liquibase validate -changelog-file changelog/controller.xml
exit
SQL

                                echo "Liquibase validate output:"
                                cat liquibase-validate.log
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
                                echo "Running Liquibase status..."

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > liquibase-status.log
liquibase status -changelog-file changelog/controller.xml
exit
SQL

                                echo "Liquibase status output:"
                                cat liquibase-status.log
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
                                echo "Generating deployment-preview.sql using Liquibase update-sql..."

                                rm -f deployment-preview.sql

                                sql -s "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_CONNECT_STRING" <<'SQL' > deployment-preview.sql
liquibase update-sql -changelog-file changelog/controller.xml
exit
SQL

                                echo "Preview SQL generated:"
                                ls -lh deployment-preview.sql

                                echo "First 80 lines of deployment-preview.sql:"
                                head -80 deployment-preview.sql || true
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
                                README.md \
                                .gitignore \
                                Jenkinsfile \
                                deployment-preview.sql \
                                db-health-check.log \
                                liquibase-validate.log \
                                liquibase-status.log

                            echo "Release ZIP created:"
                            ls -lh "${RELEASE_ZIP}"
                        '''
                    }
                }

                stage('Archive CI Artifacts') {
                    steps {
                        archiveArtifacts artifacts: '''
                            deployment-preview.sql,
                            db-health-check.log,
                            liquibase-validate.log,
                            liquibase-status.log,
                            oracle-db-cicd-demo-*.zip
                        ''', fingerprint: true
                    }
                }
            }

            post {
                always {
                    echo "Cleaning Oracle DB CI workspace"
                    deleteDir()
                }
            }
        }
    }

    post {
        always {
            echo "Oracle DB CI preview pipeline finished"
            deleteDir()
        }

        failure {
            echo "Oracle DB CI pipeline failed. Check DB connection, Liquibase changelog, or SQLcl logs."
        }

        success {
            echo "Oracle DB CI pipeline completed successfully. Preview SQL and release ZIP were archived."
        }
    }
}