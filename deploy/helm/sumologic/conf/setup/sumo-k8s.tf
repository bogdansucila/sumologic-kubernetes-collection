{{- $logs := (dict "name" "logs" "value" "logs" "endpoint" "logs" )}}
{{- $events := (dict "name" "events" "value" "events" "endpoint" "events" "category" true )}}
variable "cluster_name" {
  type  = string
  default = "{{ template "sumologic.clusterNameReplaceSpaceWithDash" . }}"
}

{{- if .Values.sumologic.collectorName }}
variable "collector_name" {
  type  = string
  default = "{{ .Values.sumologic.collectorName }}"
}
{{- else }}
variable "collector_name" {
  type  = string
  default = "{{ template "sumologic.clusterNameReplaceSpaceWithDash" . }}"
}
{{- end }}

variable "namespace_name" {
  type  = string
  default = "{{ .Release.Namespace }}"
}

locals {
{{- range $source := .Values.sumologic.sources }}
  {{ template "terraform.sources.local" $source }}
{{- end }}
  {{ template "terraform.sources.local" $logs }}
  {{ template "terraform.sources.local" $events }}
}

provider "sumologic" {}

resource "sumologic_collector" "collector" {
    name  = var.collector_name
    fields  = {
      cluster = var.cluster_name
    }
}

{{- $ctx := .Values -}}
{{- range $source := .Values.sumologic.sources }}
{{ include "terraform.sources.resource" (dict "Source" $source "Context" $ctx) | nindent 2 }}
{{- end }}
{{ include "terraform.sources.resource" (dict "Source" $logs "Context" $ctx) | nindent 2 }}
{{ include "terraform.sources.resource" (dict "Source" $events "Context" $ctx) | nindent 2 }}

provider "kubernetes" {
{{- $ctx := .Values -}}
{{ $printf_str := "%-25s" }}
{{ range $key, $value := .Values.sumologic.cluster }}
  {{ if eq $key "exec" }}
  exec {
    command = "{{ $ctx.sumologic.cluster.exec.command }}"
    {{ if hasKey $ctx.sumologic.cluster.exec "api_version" }}{{ printf $printf_str "api_version" }} = "{{ $ctx.sumologic.cluster.exec.api_version }}"{{ end }}
    {{ if hasKey $ctx.sumologic.cluster.exec "args" }}
    {{ printf $printf_str "args" }} = {{ toJson $ctx.sumologic.cluster.exec.args }}
    {{- end -}}
    {{ if hasKey $ctx.sumologic.cluster.exec "env" }}
    {{ printf $printf_str "env" }} = {
      {{ range $key_env, $value_env := $ctx.sumologic.cluster.exec.env }}
        {{ printf $printf_str $key_env }} = "{{ $value_env }}"
      {{- end -}}
    }
    {{ end }}
  }
  {{- else -}}
  {{ printf "  %-25s" $key }} = "{{ $value }}"
  {{- end -}}
{{- end }}
}

resource "kubernetes_namespace" "sumologic_collection_namespace" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_secret" "sumologic_collection_secret" {
  metadata {
    name = "sumologic"
    namespace = var.namespace_name
  }

  data = {
    {{ range $source := .Values.sumologic.sources -}}
    {{ include "terraform.sources.data" $source }}
    {{ end -}}
    {{ include "terraform.sources.data" $logs }}
    {{ include "terraform.sources.data" $events }}
  }

  type = "Opaque"
}