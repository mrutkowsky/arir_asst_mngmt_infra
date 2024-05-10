variable "pstgrsql_admin_login" {
  description = "Login for postgresql server admin account."
}

variable "pstgrsql_admin_password" {
  description = "Password for postgresql server admin account."
  sensitive   = true
}