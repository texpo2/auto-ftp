# VM 프로비저닝 - FTP 서버 설정
resource "null_resource" "vm_provisioner" {
  # VM이 변경될 때마다 다시 실행
  triggers = {
    vm_id = azurerm_linux_virtual_machine.vm.id
  }

  # VM 생성 완료 후 실행
  depends_on = [azurerm_linux_virtual_machine.vm]

  # 파일 복사와 실행을 한 번에 처리
  provisioner "file" {
    source      = "setup_ftp_server.sh"
    destination = "/home/azureuser/setup_ftp_server.sh"

    connection {
      type     = "ssh"
      user     = "azureuser"
      password = var.admin_password
      host     = azurerm_public_ip.vm_pip.ip_address
      timeout  = "10m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/azureuser/setup_ftp_server.sh",
      "sudo /home/azureuser/setup_ftp_server.sh"
    ]

    connection {
      type     = "ssh"
      user     = "azureuser"
      password = var.admin_password
      host     = azurerm_public_ip.vm_pip.ip_address
      timeout  = "30m"
    }
  }
}

# 프로비저닝 상태 출력
output "provisioning_status" {
  value = "VM provisioned with FTP server configuration"
  depends_on = [null_resource.vm_provisioner]
}