{{- define "sd.labels" -}}
app.kubernetes.io/part-of: servicedesk
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "sd.image" -}}
{{ .root.Values.image.registry }}/{{ .name }}:{{ .root.Values.image.tag }}
{{- end }}

{{/* Pod-level bits shared by every workload: workload identity + Key Vault CSI mount */}}
{{- define "sd.podSpecCommon" -}}
serviceAccountName: {{ .Values.serviceAccount.name }}
securityContext:
  runAsNonRoot: true
  seccompProfile: { type: RuntimeDefault }
volumes:
  - name: kv-secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: servicedesk-kv
{{- end }}

{{- define "sd.kvMount" -}}
volumeMounts:
  - name: kv-secrets
    mountPath: /mnt/secrets
    readOnly: true
{{- end }}

{{- define "sd.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities: { drop: ["ALL"] }
{{- end }}
