pipeline {
    agent {
        label 'build-node'
    }
    
    environment {
        DOCKER_CREDS = credentials('docker-hub-credentials')
    }
        
    stages {
        stage('Cleanup') {
            steps {
                sh '''
                    sudo docker system prune -f
                    git clean -ffdx -e "*.tfstate*" -e ".terraform/*"
                '''
            }
        }

        stage('Tests') {
            steps {
                sh '''
                    cd backend
                    python3 -m pip install -r requirements.txt
                    
                    # Use sqlite for tests
                    export DJANGO_TEST_DATABASE=sqlite
                    
                    # Create migrations if they don't exist
                    python3 manage.py makemigrations
                    
                    # Apply migrations to SQLite
                    python3 manage.py migrate
                    
                    # Run the tests with SQLite
                    python3 manage.py test product.tests
                '''
            }
        }

        stage('Build & Push Images') {
            steps {
                sh 'echo $DOCKER_CREDS_PSW | sudo docker login -u $DOCKER_CREDS_USR --password-stdin'
                
                sh """
                    sudo docker build \
                        -t morenodoesinfra/ecommerce-be:latest \
                        -f Dockerfile.backend .
                    
                    sudo docker push morenodoesinfra/ecommerce-be:latest
                """
                
                sh """
                    sudo docker build \
                        -t morenodoesinfra/ecommerce-fe:latest \
                        -f Dockerfile.frontend .
                        
                    sudo docker push morenodoesinfra/ecommerce-fe:latest
                """
            }
        }

        stage('GCP Infrastructure') {
            steps {
                sh 'gcloud auth list'
                
                dir('terraform') {
                    sh '''
                        terraform init
                        terraform apply -auto-approve \
                            -var="dockerhub_username=${DOCKER_CREDS_USR}" \
                            -var="dockerhub_password=${DOCKER_CREDS_PSW}" \
                            -var="service_account_email=${GCP_SERVICE_ACCOUNT}"
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
        success {
            echo 'Deployment to GCP completed successfully!'
        }
        failure {
            echo 'Deployment to GCP failed. Check the logs for details.'
        }
    }
}