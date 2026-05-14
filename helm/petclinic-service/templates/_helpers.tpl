{{/*
Resolve the microservice name. Each release of this generic chart deploys one service.
*/}}
{{- define "petclinic-service.name" -}}
{{- default .Values.service.name .Values.nameOverride | required "service.name or nameOverride is required" -}}
{{- end -}}

{{/*
Resolve the Kubernetes object name for this service release.
*/}}
{{- define "petclinic-service.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "petclinic-service.name" . | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "petclinic-service.commonLabels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: petclinic
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "petclinic-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "petclinic-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Image reference. If image.repository is empty, build it from repositoryPrefix + service name.
*/}}
{{- define "petclinic-service.image" -}}
{{- $serviceName := include "petclinic-service.name" . -}}
{{- $prefix := trimSuffix "-" (default "" .Values.image.repositoryPrefix) -}}
{{- $defaultRepository := $serviceName -}}
{{- if $prefix -}}
{{- $defaultRepository = printf "%s-%s" $prefix $serviceName -}}
{{- end -}}
{{- $repository := default $defaultRepository .Values.image.repository -}}
{{- $tag := required "image.tag is required" .Values.image.tag -}}
{{- if .Values.image.registry -}}{{ .Values.image.registry }}/{{ end -}}{{ $repository }}:{{ $tag }}
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "petclinic-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "petclinic-service.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
