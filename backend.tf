terraform {
  cloud {
    organization = "DevOps2026"

    workspaces {
      name = "Cloud-Infrastructure"
    }
  }
}