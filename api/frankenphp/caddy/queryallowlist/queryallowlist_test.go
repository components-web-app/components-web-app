package queryallowlist

import "testing"

func TestFilter(t *testing.T) {
	keep := []string{"page", "search", "order", "cwa_force"}
	cases := []struct {
		in, want string
		changed  bool
	}{
		{"x=123", "", true},
		{"page=2", "page=2", false},
		{"page=2&x=1", "page=2", true},
		{"x=1&page=2&utm_source=a&search=b%20c", "page=2&search=b%20c", true},
		{"order[title]=asc&order%5BcreatedAt%5D=desc&orderx=1", "order[title]=asc&order%5BcreatedAt%5D=desc", true},
		{"pages=1&page", "page", true},
		{"page=1&&search=", "page=1&search=", true},
		{"%zz=1&page=1", "page=1", true},
		{"vue&type=style&index=0&lang.css", "", true},
	}
	for _, c := range cases {
		got, changed := Filter(c.in, keep)
		if got != c.want || changed != c.changed {
			t.Errorf("Filter(%q) = %q, %v; want %q, %v", c.in, got, changed, c.want, c.changed)
		}
	}

	if got, changed := Filter("x=1&vue", []string{"*"}); got != "x=1&vue" || changed {
		t.Errorf("* must keep everything, got %q, %v", got, changed)
	}
}
