pipeline {
    agent any
    
    tools {
        
        maven 'maven3'
    }
    
    environment {
        
     scannerHome = tool 'sonar-tool'
            
    }

    stages {
      
        stage('code compile') {
            steps {
                sh 'mvn compile'
            }
        }
        
        stage('code test') {
            steps {
                sh 'mvn test'
            }
        }
        
         stage('install') {
            steps {
                sh "mvn clean install"
            }
        }
        
        
        stage('SonarQube analysis') {
          steps {
            
            withSonarQubeEnv('sonar-scanner') {
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
                        dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dp-check'
                        dependencyCheckPublisher pattern: 'dependency-check-report.xml'
                    }
                }
            }
        }  
    }
}
