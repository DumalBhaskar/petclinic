pipeline {
    agent any
    
    tools {
        
        maven 'maven3'
    }
    
    environment {
     COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()    
     IMAGE_NAME =  'dumalbhaskar/petclinic'
     IMAGE_TAG  =  "${BUILD_NUMBER}-${COMMIT_ID}"
     DOCKER_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
     scannerHome = tool 'sonar-scanner'
            
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

       stage("Trivy-docker-image-scanning") {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh "trivy image --no-progress --exit-code 1 --severity HIGH,CRITICAL --format json -o trivy_report.json ${DOCKER_IMAGE}"
                    sh "trivy image --format pdf -o trivy_report.pdf ${DOCKER_IMAGE}"
                    archiveArtifacts artifacts: 'trivy_report.pdf', allowEmptyArchive: true 
                }
            }
        }

        
        
    }
}
