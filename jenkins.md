scripted pipeline:
----------------------------------------------------------------
pipeline script :
    
    node('t2smalljdk_mvn') {
         stage('spring_script') {
         git url:'https://github.com/spring-petclinic/spring-framework-petclinic.git',
          branch: 'master'
}
 stage('bulid'){
   sh 'mvn package'  
 }
}