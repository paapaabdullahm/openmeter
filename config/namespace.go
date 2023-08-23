package config

import (
	"errors"

	"github.com/spf13/viper"
)

// Namespace configuration
type NamespaceConfiguration struct {
	Default           string
	DisableManagement bool
}

func (c NamespaceConfiguration) Validate() error {
	if c.Default == "" {
		return errors.New("default namespace is required")
	}

	return nil
}

// configureNamespace configures some defaults in the Viper instance.
func configureNamespace(v *viper.Viper) {
	v.SetDefault("namespace.default", "default")
	v.SetDefault("namespace.disableManagement", false)
}
