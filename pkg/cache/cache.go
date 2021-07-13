package cache

import (
	"time"
)

type Cache struct {
	lastRefreshTime time.Time
	bridges         map[string]bool
}

func (c *Cache) Refresh(freshBridges map[string]bool) {
	c.bridges = freshBridges
	c.lastRefreshTime = time.Now()
}

func (c *Cache) LastRefreshTime() time.Time {
	return c.lastRefreshTime
}

func (c Cache) Bridges() map[string]bool {
	bridgesCopy := make(map[string]bool)
	for bridge, exist := range c.bridges {
		bridgesCopy[bridge] = exist
	}
	return bridgesCopy
}
