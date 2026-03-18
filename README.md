проект для развертывания инфраструктуры в Yandex.Cloud с помощью Terraform и Ansible. Создает изолированные окружения (`prod` и `test`) с виртуальными машинами, сетевым балансировщиком и DNS, а также автоматически генерирует инвентарь для Ansible.

## Структура

*   `terraform/`: Основной код для создания инфраструктуры.
    *   `global/`: Глобальные ресурсы, общие для всех окружений (основная сеть, DNS-зона).
    *   `modules/`: Переиспользуемые модули Terraform (сеть, ВМ, балансировщик, DNS).
    *   `environments/`: Конфигурации для разных окружений (`prod`, `test`). Каждое окружение разворачивает свой стек из модулей.
*   `ansible/`: Плейбуки для настройки созданных ВМ.
    *   `inventory/`: Сюда Terraform генерирует файлы инвентаря (`prod_hosts`, `test_hosts`).
    *   `docker-playbook.yml`: Установка Docker на целевые хосты.
    *   `prometheus-and-grafana-playbook.yml`: Развертывание стека мониторинга.

## Окружения

*   **`prod`** (production-like):
    *   Сеть `192.168.20.0/24`.
    *   1 ВМ для приложения (`app`), 1 ВМ для мониторинга (`monitoring`).
    *   Сетевой балансировщик для приложений, DNS-запись для доступа.
*   **`test`**:
    *   Сеть `192.168.10.0/24`.
    *   1 ВМ для приложения, 1 ВМ для мониторинга.
    *   Балансировщик и DNS-запись.

## Как это работает

1.  **Terraform** (из папки окружения, например `environments/prod`):
    *   Создает ресурсы в Yandex.Cloud, используя объявленные модули.
    *   После создания ВМ, на основе их IP-адресов, с помощью `ip-for-ansible.tf` генерирует два файла инвентаря в `ansible/inventory/`: `prod_hosts` и `test_hosts`.
2.  **Ansible**:
    *   Использует сгенерированные инвентари для подключения к ВМ.
    *   Плейбук `docker-playbook.yml` ставит Docker на все хосты из группы `app` и `monitoring`.
    *   Плейбук `prometheus-and-grafana-playbook.yml` настраивает мониторинг:
        *   На хостах `app_ext` (ВМ приложений) запускает node_exporter, cadvisor, blackbox_exporter, promtail.
        *   На хосте `monitoring_ext` (ВМ мониторинга) запускает Prometheus, Grafana, Loki и тоже promtail.

## Переменные и секреты

Terraform-код ожидает переменные:
*   `token` (OAuth-токен Yandex.Cloud)
*   `cloud_id`
*   `folder_id`

Их нужно передавать при запуске (например, через `terraform.tfvars`).

## Что нужно, чтобы заработало

- Terraform (>= 0.13) и Ansible.
- Аккаунт в Yandex Cloud, сервисный аккаунт, OAuth-токен.
- SSH-ключи (публичная часть) в `~/.ssh/timeweb.pub`.

## Как запускать

### 1. Поднимаем инфраструктуру Terraform'ом. Создаем сеть и DNS зону.
cd terraform/global/
создайте terraform.tfvars со своими token, cloud_id, folder_id
terraform init
terraform plan
terraform apply

### 2. Поднимаем кластер (на примере prod)
cd terraform/global/environments/prod
создайте terraform.tfvars со своими token, cloud_id, folder_id
terraform init
terraform plan
terraform apply

### 3. Настраиваем виртуалки Ansible
- Убедитесь, что машины созданы и доступны по SSH.
- Пропишите их IP или DNS в инвентарном файле (например, `inventory.ini`) с группами `all`, `app_ext`, `monitoring_ext`.
- Запускайте плейбуки:
# Ставим Docker везде
ansible-playbook -i inventory.ini ansible/docker-playbook.yml

# Ставим мониторинг
ansible-playbook -i inventory.ini ansible/prometheus-and-grafana-playbook.yml
