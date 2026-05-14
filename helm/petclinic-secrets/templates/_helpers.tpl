{{/*
Common labels for shared Petclinic secret resources.
*/}}
{{- define "petclinic-secrets.commonLabels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: petclinic
{{- end -}}
