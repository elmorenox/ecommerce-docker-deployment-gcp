pipeline {
    agent {
        label 'build-node'
    }
    
    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
    }
        
    stages {
        stage('Destroy GCP Infrastructure') {
            steps {
                input message: 'Are you sure you want to destroy the infrastructure?', ok: 'Yes, destroy it'
                
                sh '''
                    # Get project ID from instance metadata
                    PROJECT_ID=$(gcloud config get-value project)
                    echo "project id: $PROJECT_ID"                    
                    
                    # Get service account email from instance metadata
                    SERVICE_ACCOUNT=$(gcloud auth list --format="value(account)" | head -n 1)
                    echo "svc account: $SERVICE_ACCOUNT"

                    # Use these values in Terraform
                    cd terraform
                    terraform init
                    
                    terraform destroy -auto-approve \
                        -var="project_id=${PROJECT_ID}" \
                        -var="service_account_email=${SERVICE_ACCOUNT}" \
                        -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                        -var="dockerhub_password=${DOCKER_CREDS_PSW}"
                '''
            }
        }
    }
    
    post {
        success {
            echo 'Infrastructure destroyed successfully!'
        }
        failure {
            echo 'Failed to destroy infrastructure. Check the logs for details.'
        }
    }
}