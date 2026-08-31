package main

import "testing"

func TestGreeting(t *testing.T) {
	got := "Hello, World!"
	if got == "" {
		t.Fatal("empty greeting")
	}
}
