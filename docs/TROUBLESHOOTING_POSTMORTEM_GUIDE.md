# DevOps & SRE Troubleshooting Guide & Incident Postmortems

> **Repository:** `devopsatolyesi-labs/ecommerce-sre-slo-opentelemetry`  
> **Target Environment:** AWS EKS (`astronomy-shop-dev`), Traefik v3, Kubernetes Gateway API v1, cert-manager (Let's Encrypt), Cloudflare DNS-Only.  
> **Status:** Production-Ready & Operational  
> **Author:** DevOps Atölyesi SRE Team

---

## 1. Mimari ve Çalışma Modeli (Architecture Overview)

Bu projede geleneksel, artık kullanım ömrünü tamamlamış (deprecated) olan `ingress-nginx` veya AWS ACM'e bağımlı klasik Ingress modelleri yerine modern **CNCF Kubernetes Gateway API v1 (`gateway.networking.k8s.io/v1`)** ve **Traefik v3 Controller** mimarisi kullanılmıştır.

```text
[ İnternet İstemcisi / Browser ]
           │
           │  (DNS: Cloudflare DNS-Only / proxied: false)
           ▼
[ AWS Load Balancer (ELB / NLB) - Layer 4 TCP Passthrough ]
           │  Port 80 (TCP)  -->  NodePort 31835
           │  Port 443 (TCP) -->  NodePort 30877
           ▼
[ Traefik v3 Gateway Controller Pod (Namespace: traefik) ]
   ├── Listener "web"       (Port 8000 / HTTP)
   └── Listener "websecure" (Port 8443 / HTTPS - TLS Termination via Secret: sre-platform-tls)
           │
   ┌───────┴──────────────────────────────┐
   │                                      │
   ▼ HTTPRoute                            ▼ HTTPRoute
[ astronomy-shop-route ]               [ grafana-route ]
   │                                      │
   ▼                                      ▼
Service: frontend-proxy:8080          Service: grafana:80 -> Container: 3000
(Namespace: astronomy-shop)           (Namespace: monitoring)
```

### Temel Prensipler:
1. **AWS Load Balancer (L4 Passthrough):** AWS Load Balancer 7. Katman (HTTP/HTTPS) olarak değil, **4. Katman (Layer 4 TCP)** modunda çalışır. Gelen paketleri çözmeden doğrudan cluster içindeki Traefik Gateway'e iletir. AWS tarafında ACM sertifikası yüklenmez.
2. **TLS Sonlandırma (Kubernetes İçinde):** SSL sertifikası Kubernetes içinde `cert-manager` ve `ClusterIssuer (letsencrypt-prod)` tarafından otomatik üretilir, yenilenir ve `traefik-gateway` dinleyicisine bağlanır.
3. **Cloudflare DNS-Only Kuralı:** Let's Encrypt HTTP-01 challenge doğrulamasının Cloudflare CDN önbelleğine veya yönlendirme döngüsüne takılmaması için tüm DNS kayıtları `proxied: false` (gri bulut) olarak yönetilir.

---

## 2. Karşılaşılan Sorunlar, Kök Neden Analizleri ve Çözümleri (Postmortems)

---

### Postmortem 1: OpenTelemetry Demo Helm Schema Validation Hatası

* **Belirti / Hata Logu:**
  ```text
  Error: values don't meet the specifications of the schema(s) in the following chart(s):
  opentelemetry-demo:
  - default: Additional property useDefault is not allowed
  ```
* **Kök Neden:**
  `observability/values-production.yaml` içinde mikroservislerin ortak çevre değişkenlerini kapatmak için yazılan `default.useDefault: false` parametresi, güncel OpenTelemetry Demo Helm chart şemasında (JSON Schema) yer almıyordu. Helm v3 `strict schema validation` uyguladığı için tüm kurulumu kilitledi ve podlar ayağa kalkmadı.
* **Uygulanan Çözüm:**
  Geçersiz `useDefault` anahtarı temizlendi. Chart şemasına tam uyumlu olan `default.envOverrides` listesi kullanılarak OTLP collector endpoint'i tanımlandı:
  ```yaml
  default:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://otel-collector.opentelemetry.svc.cluster.local:4317"
  ```

---

### Postmortem 2: cert-manager Helm Sahiplik (Ownership Metadata) Kilitlenmesi

* **Belirti / Hata Logu:**
  ```text
  Error: Unable to continue with install: Role "cert-manager-cainjector:leaderelection" in namespace "kube-system" 
  exists and cannot be imported into the current release: invalid ownership metadata; 
  label validation error: missing key "app.kubernetes.io/managed-by": must be set to "Helm"; 
  annotation validation error: missing key "meta.helm.sh/release-name": must be set to "cert-manager"
  ```
* **Kök Neden:**
  Kümede daha önce çalıştırılan testlerden veya manuel kurulumlardan kalan `kube-system` altındaki Leader Election RBAC nesneleri ve CRD'ler, Helm metadata etiketlerine (`meta.helm.sh/release-name`) sahip değildi. Helm güvenlik mekanizması gereği sahipsiz kaynakların üzerine yazmayı reddetti ve deployment adımını durdurdu.
* **Uygulanan Çözüm:**
  `cert-manager` kurulumu kırılgan Helm paketinden çıkarıldı; doğrudan resmi bildirimsel (declarative) Kubernetes manifestolarına geçirildi:
  ```bash
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
  kubectl apply -f observability/cert-manager-gateway-rbac.yaml
  kubectl patch deployment cert-manager -n cert-manager --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--feature-gates=ExperimentalGatewayAPISupport=true"}]'
  ```
  Kurulum süresi 3 dakikadan 18 saniyeye indirildi ve çakışmalar kalıcı olarak engellendi.

---

### Postmortem 3: Traefik v3 Gateway Controller CRD Reflector Crash Loop ("Waiting for controller")

* **Belirti / Hata Logu:**
  ```text
  E0905 14:06:51.706296 1 reflector.go:227] "Failed to watch" 
  err="failed to list *v1.TLSRoute: the server could not find the requested resource (get tlsroutes.gateway.networking.k8s.io)"
  
  E0905 14:06:54.824629 1 reflector.go:227] "Failed to watch" 
  err="failed to list *v1.BackendTLSPolicy: the server could not find the requested resource (get backendtlspolicies.gateway.networking.k8s.io)"
  ```
  `kubectl describe gateway -n traefik traefik-gateway`:
  ```text
  Status:
    Conditions:
      Message: Waiting for controller
  ```
  Tüm HTTP ve HTTPS istekleri `404 page not found` döndürdü.
* **Kök Neden:**
  Traefik v3 (`traefik-41.4.0` Helm chart), Kubernetes client-go v0.36 ile derlenmiştir ve **Gateway API v1.5.1** sürümündeki CRD'leri izler. Daha önce cluster'a uygulanan Gateway API `v1.2.0` paketinde `TLSRoute` ve `BackendTLSPolicy` kaynakları `v1` değil, eski `v1alpha2` seviyesindeydi. Traefik'in Kubernetes API izleyicisi (informer reflector) kaynakları bulamayınca çöktü ve döngüye girdi; bu sebeple `traefik-gateway` hiçbir zaman programlanamadı.
* **Uygulanan Çözüm:**
  Resmi Kubernetes Gateway API **v1.5.1** `standard-install.yaml` paketi Server-Side Apply ile uygulandı:
  ```bash
  kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
  ```
  `traefik-gateway` hemen **`PROGRAMMED: True`** durumuna geçti.

---

### Postmortem 4: Grafana Service Port Uyuşmazlığı (HTTP 404 / 503 Hatası)

* **Belirti / Hata Logu:**
  Gateway API programlanmasına rağmen `http://grafana.devopsatolyesi.com` adresi açılamadı.
* **Kök Neden:**
  `observability/03-grafana-deployment.yaml` içindeki Grafana Service'i yalnızca `port: 3000` açıyordu. Ancak `observability/05-unified-ingress.yaml` içindeki `HTTPRoute` kuralı trafiği `backendRefs: [{name: grafana, port: 80}]` olarak yönlendiriyordu. Hedef serviste port 80 tanımlı olmadığı için Traefik istekleri backend'e iletemedi.
* **Uygulanan Çözüm:**
  Grafana Servisi hem port 80 hem de port 3000'i karşılayacak şekilde güncellendi:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: grafana
    namespace: monitoring
  spec:
    type: ClusterIP
    selector:
      app: grafana
    ports:
      - port: 80
        targetPort: 3000
        name: http
      - port: 3000
        targetPort: 3000
        name: grafana-ui
  ```

---

### Postmortem 5: Cloudflare SSL Handshake Loop & Let's Encrypt Doğrulama Engeli

* **Belirti / Hata Logu:**
  Tarayıcıda `ERR_TOO_MANY_REDIRECTS` veya Cloudflare `Error 525: SSL Handshake Failed`.
* **Kök Neden:**
  Cloudflare üzerinde CNAME kayıtları `proxied: true` (turuncu bulut) yapıldığında, Cloudflare kenar sunucusu (edge) HTTP isteklerini kendi üzerinde HTTPS'e zorluyor ve henüz SSL kurulmamış olan backend'e bağlanırken handshake hatası veriyordu. Ayrıca Let's Encrypt ACME HTTP-01 challenge doğrulaması Cloudflare önbelleğine takılıyordu.
* **Uygulanan Çözüm:**
  CI/CD pipeline içerisindeki Cloudflare DNS senkronizasyon adımında tüm CNAME kayıtları `proxied: false` (DNS-only / gri bulut) yapıldı:
  ```json
  {"type":"CNAME","name":"grafana","content":"<ALB-HOSTNAME>","ttl":60,"proxied":false}
  ```
  İstemciler ve Let's Encrypt doğrulayıcıları doğrudan AWS Load Balancer'a bağlandı.

---

### Postmortem 6: SAN Sertifikasında İsteğe Bağlı Servis (SonarQube) Nedeniyle Tüm Sertifikanın Kilitlenmesi

* **Belirti / Hata Logu:**
  ```text
  2026-09-05T14:34:21Z ERR Unable to load HTTPRoute backend: 
  Cannot load HTTPBackendRef sonarqube/sonarqube: getting service: service "sonarqube" not found 
  http_route=sonarqube-route namespace=sonarqube
  ```
  `kubectl get certificate -A`:
  ```text
  NAMESPACE   NAME               READY   SECRET             AGE
  traefik     sre-platform-tls   False   sre-platform-tls   37m
  ```
* **Kök Neden:**
  `sre-platform-tls` sertifikası çoklu alan adı (SAN) olarak tanımlanmıştı:
  - `astronomy.devopsatolyesi.com`
  - `grafana.devopsatolyesi.com`
  - `sonar.devopsatolyesi.com`
  Pipeline'da SonarQube devre dışıyken (`deploy_sonarqube=false`) SonarQube servisi ve DNS kaydı açılmıyordu. Let's Encrypt, **SAN sertifikalarında listedeki tek bir domain bile doğrulanamazsa sertifikanın tamamını onaylamayı reddeder.** Bu sebeple çalışan diğer 2 servis de SSL alamadı. Ayrıca `sonarqube-route` cluster'da sahipsiz kalarak Traefik'i meşgul etti.
* **Uygulanan Çözüm:**
  1. `sonarqube-route` ana ingress dosyasından alınıp `06-sonarqube-deployment.yaml` içine taşındı.
  2. Pipeline'a sahipsiz route temizliği eklendi:
     ```bash
     if [ "${{ inputs.deploy_sonarqube }}" != "true" ]; then
       kubectl delete httproute -n sonarqube sonarqube-route --ignore-not-found=true || true
     fi
     ```
  3. Ana `sre-platform-tls` sertifikasından `sonar` çıkarıldı, sadece aktif olan `astronomy` ve `grafana` bırakıldı.
  4. Takılı kalan eski ACME challenge ve order nesneleri temizlendi.

---

### Postmortem 7: Dependabot Workflow Parser Çökmesi

* **Belirti / Hata Logu:**
  ```text
  dependency_file_not_parseable: /.github/workflows/99-manual-dns-fix.yml not parseable
  Error: Dependabot encountered an error performing the update
  ```
* **Kök Neden:**
  `.github/workflows/` dizini altına manuel müdahale amacıyla konulan `99-manual-dns-fix.yml` dosyası standart GitHub Actions syntax'ına sahip değildi. Dependabot ve GitHub runner bu dizindeki her `.yml` dosyasını workflow sandığı için parse edemeyip hata bildirdi.
* **Uygulanan Çözüm:**
  Dosya depodan silindi (`12d8801`) ve geçici betikler için `.github/workflows` dizini kullanılmaması kuralı getirildi.

---

### Postmortem 8: cert-manager Controller Gateway API Bayrağı ve Pod Yeniden Başlatma İhtiyacı ("gateway api is not enabled")

* **Belirti / Hata Logu:**
  ```text
  Warning  PresentError  cert-manager-challenges  
  Error presenting challenge: couldn't Present challenge traefik/sre-platform-tls-...: 
  gateway api is not enabled
  ```
  `kubectl describe challenge -A`:
  ```text
  Status:
    Presented:   false
    Processing:  true
    Reason:      couldn't Present challenge ...: gateway api is not enabled
    State:       pending
  ```
* **Kök Neden:**
  `cert-manager` v1.16+ sürümlerinde `gatewayHTTPRoute` çözücüsünü (solver) kullanabilmek için controller container'ının Gateway API desteğiyle başlaması şarttır. Eski usul JSON patch ile argüman eklemek kırılgan kalmış ve controller pod'u rollout restart edilmediği için eski pod CRD'leri algılayamadan çalışmaya devam etmiştir. `cert-manager` Gateway API CRD'lerini ve konfigürasyonunu yalnızca başlangıçta (startup) tarar.
* **Uygulanan Çözüm:**
  `cert-manager` controller Deployment'ı Strategic Merge Patch ile doğrudan güncellendi ve rollout restart uygulandı:
  ```bash
  kubectl patch deployment cert-manager -n cert-manager --type='strategic' -p '{
    "spec": {
      "template": {
        "spec": {
          "containers": [
            {
              "name": "cert-manager-controller",
              "args": [
                "--v=2",
                "--cluster-resource-namespace=$(POD_NAMESPACE)",
                "--leader-election-namespace=kube-system",
                "--acme-http01-solver-image=quay.io/jetstack/cert-manager-acmesolver:v1.16.2",
                "--max-concurrent-challenges=60",
                "--feature-gates=ExperimentalGatewayAPISupport=true",
                "--enable-gateway-api"
              ]
            }
          ]
        }
      }
    }
  }'
  kubectl rollout restart deployment cert-manager -n cert-manager
  kubectl rollout status deployment cert-manager -n cert-manager --timeout=120s
  ```

---

## 3. SRE Operasyonel Troubleshooting ve Doğrulama Rehberi (Cheat Sheet)

Sorun yaşandığında kontrol edilmesi gereken adımlar sırasıyla şunlardır:

### 1. Gateway API Durumunu İnceleme
```bash
# Gateway'in programlanıp programlanmadığını kontrol edin
kubectl get gateway,httproute -A

# Gateway detaylarını ve listener durumlarını inceleyin
kubectl describe gateway -n traefik traefik-gateway
# Beklenen: Reason: Programmed | Status: True | Listeners: No error found
```

### 2. Traefik Controller Loglarını Canlı İzleme
```bash
kubectl logs -n traefik deployment/traefik -f --tail=100
# "Failed to watch" veya "Cannot load HTTPBackendRef" hatalarını arayın.
```

### 3. cert-manager ve ACME Challenge Durumunu İnceleme
```bash
# Sertifika durumları
kubectl get certificate -A

# Takılan veya başarısız olan ACME Challenge var mı?
kubectl get challenges -A
kubectl describe challenge -A

# cert-manager controller logları
kubectl logs -n cert-manager deployment/cert-manager --tail=100
```

### 4. HTTP Port 80 ve DNS Canlı Doğrulama
```bash
# AWS ALB üzerinden Host Header testi (DNS beklemeden)
ALB=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -sIL -H "Host: grafana.devopsatolyesi.com" "http://${ALB}"
curl -sIL -H "Host: astronomy.devopsatolyesi.com" "http://${ALB}"

# Canlı DNS testi
curl -sIL http://astronomy.devopsatolyesi.com
curl -sIL http://grafana.devopsatolyesi.com
```

### 5. SSL / TLS Sertifika Detaylarını İnceleme
```bash
# Hangi sertifikanın sunulduğunu kontrol edin (Traefik Default Cert mi yoksa Let's Encrypt mi?)
echo | openssl s_client -connect astronomy.devopsatolyesi.com:443 -servername astronomy.devopsatolyesi.com 2>/dev/null | openssl x509 -noout -issuer -dates -subject
# Beklenen Issuer: C = US, O = Let's Encrypt, CN = R10 / R11
```
