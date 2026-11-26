output "instance_name" {
  value = google_compute_instance.lab.name
}

output "machine_type" {
  value = google_compute_instance.lab.machine_type
}

output "internal_ip" {
  value = google_compute_instance.lab.network_interface[0].network_ip
}

output "external_ip" {
  value = google_compute_instance.lab.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  value = "gcloud compute ssh k8s-lab --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap"
}