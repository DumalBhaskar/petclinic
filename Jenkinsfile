pipeline {
    agent any
    
    tools {
        
        maven 'maven3'
    }
    
    environment {
     COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()    
     IMAGE_NAME =  'petclinic'
     IMAGE_TAG  =  "${BUILD_NUMBER}-${COMMIT_ID}"
     // DOCKER_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
     ACCOUNT_ID = "533267075370"
     REGION  = "ap-south-1"
     DOCKER_IMAGE = "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}:${IMAGE_TAG}"
     scannerHome = tool 'sonar-scanner'
            
    }

    parameters {
        choice(name: 'OWASP_ZAP_SCAN_TYPE', choices: ['BASELINE', 'API', 'FULL'], 
               description: 'Select the OWASP ZAP scan type')

        string(name: 'ZAP_TARGET_URL', defaultValue: 'http://13.203.29.68:5000', description: 'Enter the URL of the application to scan')
    }

    stages {
      
        stage('code test') {
            steps {
                sh 'mvn test'
            }
        }
        
        
        stage('SonarQube analysis') {
          steps {
            
            withSonarQubeEnv('sonar-server') {
              sh '''
              
                     ${scannerHome}/bin/sonar-scanner \
                     -Dsonar.projectName=Petclinic \
                     -Dsonar.java.binaries=. \
                     -Dsonar.projectKey=Petclinic 
                     
                '''
            }
          }
        }
        
        
        stage("Quality Gate") {
            steps {
                script {
                    timeout(time: 1, unit: 'HOURS') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline aborted due to quality gate failure: ${qg.status}"
                        }
                    }
                }
            }
        }
        
        
        stage('Owasp Dependency Check') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    timeout(time: 60, unit: 'MINUTES') {
                        dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dp'
                        dependencyCheckPublisher pattern:'dependency-check-report.xml', failedNewCritical: 0, failedNewHigh: 0, failedTotalCritical: 0, failedTotalHigh: 0, unstableNewCritical: 0, unstableNewHigh: 0, unstableTotalCritical: 0, unstableTotalHigh: 0
                        
                    }
                }
            }
        }  
        
        
        stage('install') {
            steps {
                
                sh "mvn clean package"
            }
        }
        
        stage('hadolint') {
            steps {
                
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {   
                    
                   sh 'docker run --rm -i hadolint/hadolint < Dockerfile > hadolint_report.txt'
                }  
                
               archiveArtifacts artifacts: 'hadolint_report.txt', allowEmptyArchive: true

            }
        }
        
        stage('image-build') {
            steps {
                
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        // stage('Scan Docker Image with Trivy') {
        //     steps {
        //         script {
        //             sh "docker pull aquasec/trivy:0.56.2"
        //             retry(10) {
        //                 try {
        //                     sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -i aquasec/trivy:0.56.2 image ${DOCKER_IMAGE} > trivy_report.json"
        //                 } catch (Exception e) {
        //                     echo "Trivy scan failed: ${e.message}"
        //                     sleep 5
        //                     throw e
        //                 }
        //             }
        //         }
        //     }
        // }

        stage('OWASP ZAP Scan') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    script {
                        echo "The OWASP ZAP Scan Type is ${params.OWASP_ZAP_SCAN_TYPE}"
                        def zapScanScript = ''
                        def zapTargetUrl = params.ZAP_TARGET_URL
                        if (params.OWASP_ZAP_SCAN_TYPE == 'BASELINE') {
                            zapScanScript = 'zap-baseline.py'
                        } else if (params.OWASP_ZAP_SCAN_TYPE == 'API') {
                            zapScanScript = 'zap-api-scan.py'
                        } else if (params.OWASP_ZAP_SCAN_TYPE == 'FULL') {
                            zapScanScript = 'zap-full-scan.py'
                        }

                        def status = sh(script: """#!/bin/bash
                        docker run -t ghcr.io/zaproxy/zaproxy:stable ${zapScanScript} \
                        -t ${zapTargetUrl} > ${OWASP_ZAP_SCAN_TYPE}_Owasp_Zap_report.html
                        """, returnStatus: true)

                        if (status == 0) {
                            echo "ZAP scan completed successfully."
                        } else {
                            error "ZAP scan failed with status code: ${status}"
                        }
                    }
                }
            }
        }
        
        stage('Archive Owasp Zap Report') {
            steps {
                archiveArtifacts artifacts: "${params.OWASP_ZAP_SCAN_TYPE}_Owasp_Zap_report.html", allowEmptyArchive: false
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                script {
                    sh '''
                    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
                    docker push $DOCKER_IMAGE '''
                }
            }
        }

       stage('Docker Image Vulnerability Scan with Trivy') {
            steps {
                script {
           
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {   
                        sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL --format json -o trivy_report.json $DOCKER_IMAGE'
                    
                        archiveArtifacts artifacts: 'trivy_report.json', allowEmptyArchive: false
                    
                        sh '''
                            echo "<!DOCTYPE html>" > trivy_report.html
                            echo "<html lang='en'>" >> trivy_report.html
                            echo "<head>" >> trivy_report.html
                            echo "<meta charset='UTF-8'>" >> trivy_report.html
                            echo "<title>Trivy Vulnerability Report</title>" >> trivy_report.html
                            echo "</head>" >> trivy_report.html
                            echo "<body>" >> trivy_report.html
                            echo "<h2>Trivy Vulnerability Report</h2><pre>" >> trivy_report.html
                            jq '.' trivy_report.json >> trivy_report.html
                            echo "</pre></body></html>" >> trivy_report.html
                        '''
                    
                        sh 'wkhtmltopdf trivy_report.html trivy_report.pdf'
        
                        archiveArtifacts artifacts: 'trivy_report.html, trivy_report.pdf', allowEmptyArchive: true
                    }
              
                }
            }
        }
        
        
    }

    post {
            always {
                slackSend(
                    color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
                    message: "Build ${currentBuild.fullDisplayName} - ${currentBuild.result}.\nTriggered by: ${currentBuild.getBuildCauses()[0]?.userId}\nLink: ${env.BUILD_URL}"
                )

                emailext(
                    subject: "Jenkins Build: ${currentBuild.fullDisplayName} - ${currentBuild.result}",
                    body: """<p>Build Status: ${currentBuild.result}</p>
                            <p>Commit ID: ${env.GIT_COMMIT}</p>
                            <p>Triggered By: ${currentBuild.getBuildCauses()[0]?.userId}</p>
                            <p>Build URL: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                            <p>Attached Reports:</p>
                            <ul>
                                <li>Trivy Report: trivy_report.html</li>
                                <li>Hadolint Report: hadolint_report.html</li>
                                <li>OWASP ZAP Report: zap_report.html</li>
                            </ul>""",
                    attachmentsPattern: "trivy_report.json, hadolint_report.txt, ${params.OWASP_ZAP_SCAN_TYPE}_Owasp_Zap_report.html",
                    to: 'dumalbhaskar@gmail.com'
                )
                
                
        
            }
        }

    



    
}
