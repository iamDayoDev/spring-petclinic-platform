{{/*
Chart name
*/}}
{{- define "petclinic.name" -}}
{{- .Chart.Name }}
{{- end }}

{{/*
Common labels — pass root context ($)
*/}}
{{- define "petclinic.commonLabels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ .Chart.Name }}
{{- end }}

{{/*
Selector labels — call with dict "name" <svcName> "release" $.Release.Name
*/}}
{{- define "petclinic.selectorLabels" -}}
app.kubernetes.io/name: {{ index . "name" }}
app.kubernetes.io/instance: {{ index . "release" }}
{{- end }}

{{/*
Image reference — call with dict "registry" <reg> "name" <svcName> "tag" <tag>
*/}}
{{- define "petclinic.image" -}}
{{ index . "registry" }}/{{ index . "name" }}:{{ index . "tag" }}
{{- end }}
