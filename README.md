README.md

# TaskFlow - DevOps Portfolio Project

A modern task management application built with React, Node.js, and deployed on AWS ECS with Terraform.

## 🚀 Features

- ✅ Add, edit, delete tasks
- ✅ Mark tasks as complete/incomplete
- ✅ Beautiful, responsive UI
- ✅ RESTful API backend
- ✅ Containerized with Docker
- ✅ Infrastructure as Code with Terraform
- ✅ AWS ECS Fargate deployment
- ✅ Application Load Balancer
- ✅ CloudWatch logging

## 🏗 Architecture
 React Frontend ] → [ ALB ] → [ Node.js Backend ]
↓ ↓
[ ECS Fargate ] [ ECS Fargate ]


## 🛠 Local Development

### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- AWS CLI configured

### 1. Clone and setup
```bash
git clone <repository-url>
cd taskflow
