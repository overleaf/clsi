String cron_string = BRANCH_NAME == "master" ? "@daily" : ""

pipeline {
  agent any

  environment {
    GIT_PROJECT = "clsi-sharelatex"
    JENKINS_WORKFLOW = "clsi-sharelatex"
    TARGET_URL = "${env.JENKINS_URL}blue/organizations/jenkins/${JENKINS_WORKFLOW}/detail/$BRANCH_NAME/$BUILD_NUMBER/pipeline"
    GIT_API_URL = "https://api.github.com/repos/sharelatex/${GIT_PROJECT}/statuses/$GIT_COMMIT"
  }

  triggers {
    pollSCM('* * * * *')
    cron(cron_string)
  }

  stages {
    stage('Install') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'a6330abf-9cd7-4bfa-b472-67d438f27a24', usernameVariable: 'GH_AUTH_USERNAME', passwordVariable: 'GH_AUTH_PASSWORD')]) {
          sh "curl $GIT_API_URL \
            --data '{ \
            \"state\" : \"pending\", \
            \"target_url\": \"$TARGET_URL\", \
            \"description\": \"Your build is underway\", \
            \"context\": \"ci/jenkins\" }' \
            -u $GH_AUTH_USERNAME:$GH_AUTH_PASSWORD"
        }
      }
    }

    stage('Build') {
      steps {
        sh 'make build'
      }
    }

    stage('Unit Tests') {
      steps {
        sh 'DOCKER_COMPOSE_FLAGS="-f docker-compose.ci.yml" make test_unit'
      }
    }

    stage('Acceptance Tests') {
      steps {
        sh 'DOCKER_COMPOSE_FLAGS="-f docker-compose.ci.yml" make test_acceptance'
      }
    }

    stage('Package and publish build') {
      steps {
        
        withCredentials([file(credentialsId: 'gcr.io_csh-gcdm-test', variable: 'DOCKER_REPO_KEY_PATH')]) {
          sh 'docker login -u _json_key --password-stdin https://gcr.io/csh-gcdm-test < ${DOCKER_REPO_KEY_PATH}'
        }
        sh 'DOCKER_REPO=gcr.io/csh-gcdm-test make publish'
        sh 'docker logout https://gcr.io/csh-gcdm-test'
        
        withCredentials([file(credentialsId: 'gcr.io_csh-staging', variable: 'DOCKER_REPO_KEY_PATH')]) {
          sh 'docker login -u _json_key --password-stdin https://gcr.io/csh-staging < ${DOCKER_REPO_KEY_PATH}'
        }
        sh 'DOCKER_REPO=gcr.io/csh-staging make publish'
        sh 'docker logout https://gcr.io/csh-staging'
        
      }
    }

    stage('Publish build number') {
      steps {
        sh 'echo ${BRANCH_NAME}-${BUILD_NUMBER} > build_number.txt'
        withAWS(credentials:'S3_CI_BUILDS_AWS_KEYS', region:"${S3_REGION_BUILD_ARTEFACTS}") {
            // The deployment process uses this file to figure out the latest build
            s3Upload(file:'build_number.txt', bucket:"${S3_BUCKET_BUILD_ARTEFACTS}", path:"${JOB_NAME}/latest")
        }
      }
    }
  }

  post {
    always {
      sh 'DOCKER_COMPOSE_FLAGS="-f docker-compose.ci.yml" make test_clean'
      sh 'make clean'
    }

    success {
      withCredentials([usernamePassword(credentialsId: 'a6330abf-9cd7-4bfa-b472-67d438f27a24', usernameVariable: 'GH_AUTH_USERNAME', passwordVariable: 'GH_AUTH_PASSWORD')]) {
        sh "curl $GIT_API_URL \
          --data '{ \
          \"state\" : \"success\", \
          \"target_url\": \"$TARGET_URL\", \
          \"description\": \"Your build succeeded!\", \
          \"context\": \"ci/jenkins\" }' \
          -u $GH_AUTH_USERNAME:$GH_AUTH_PASSWORD"
      }
    }

    failure {
      mail(from: "${EMAIL_ALERT_FROM}",
           to: "${EMAIL_ALERT_TO}",
           subject: "Jenkins build failed: ${JOB_NAME}:${BUILD_NUMBER}",
           body: "Build: ${BUILD_URL}")
      withCredentials([usernamePassword(credentialsId: 'a6330abf-9cd7-4bfa-b472-67d438f27a24', usernameVariable: 'GH_AUTH_USERNAME', passwordVariable: 'GH_AUTH_PASSWORD')]) {
        sh "curl $GIT_API_URL \
          --data '{ \
          \"state\" : \"failure\", \
          \"target_url\": \"$TARGET_URL\", \
          \"description\": \"Your build failed\", \
          \"context\": \"ci/jenkins\" }' \
          -u $GH_AUTH_USERNAME:$GH_AUTH_PASSWORD"
      }
    }
  }

  // The options directive is for configuration that applies to the whole job.
  options {
    // we'd like to make sure remove old builds, so we don't fill up our storage!
    buildDiscarder(logRotator(numToKeepStr:'50'))

    // And we'd really like to be sure that this build doesn't hang forever, so let's time it out after:
    timeout(time: 30, unit: 'MINUTES')
  }
}
