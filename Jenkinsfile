pipeline {
    agent {
        label 'build-node'
    }
    
    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
        AWS_CREDS = credentials('aws-credentials')
    }
    
    stages {
        stage('Cleanup') {
            steps {
                sh '''
                    # Only clean Docker system
                    sudo docker system prune -f
                    
                    # Safer git clean that preserves terraform state
                    git clean -ffdx -e "*.tfstate*" -e ".terraform/*"
                '''
            }
        }

        stage('Tests') {
            steps {
                sh '''
                    cd backend
                    python3 -m pip install -r requirements.txt
                    python3 manage.py test product.tests
                '''
            }
        }

        stage('Build & Push Images') {
            steps {
                sh 'echo $DOCKER_CREDS_PSW | sudo docker login -u $DOCKER_CREDS_USR --password-stdin'
                
                // Build and push backend
                sh """
                    sudo docker build \
                        -t morenodoesinfra/ecommerce-be:latest \
                        -f Dockerfile.backend .
                    
                    sudo docker push morenodoesinfra/ecommerce-be:latest
                """
                
                // Build and push frontend
                sh """
                   sudo docker build \
                        -t morenodoesinfra/ecommerce-fe:latest \
                        -f Dockerfile.frontend .
                        
                    sudo docker push morenodoesinfra/ecommerce-fe:latest
                """
            }
        }

        stage('Infrastructure') {
            steps {
                dir('terraform') {
                    sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_CREDS_USR
                        export AWS_SECRET_ACCESS_KEY=$AWS_CREDS_PSW
                        terraform init
                        terraform apply -auto-approve \
                            -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                            -var="dockerhub_password=${DOCKER_CREDS_PSW}"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            sh '''
                sudo docker logout
                sudo docker system prune -f
            '''
        }
    }
}
