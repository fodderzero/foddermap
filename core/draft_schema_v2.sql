-- =====================================================
-- FodderMap brain.db Draft Schema
-- version 2
-- Started: July 21, 2026
-- Completed: July 23, 2026
-- =====================================================
--
-- ********************Summary**************************
-- 
-- Log key project metadata
-- **** project_data 
--
-- Node Tables:
-- **** scans (history nodes) 
-- **** assets (nodes) 
-- **** ips (nodes) 
--
-- Edge Tables:
-- **** ip_mappings (ips to assets / technically a junction)
-- **** relationships (assets to assets)
--
-- Hybrid Node/Edge Tables
-- **** dns_records
-- **** endpoints
--
-- Junction Tables:
-- **** scan_assets (scans to assets)
-- **** scan_ip_mappings (scans to ip mappings)
-- **** scan_relationships (scans to relationships)
--
-- *****************************************************

-- Project metadata stored in key/value pairs
-- Python will run something like:
-- INSERT INTO project_data VALUES ('project_name', 'myproject')
CREATE TABLE project_data (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Scans (track individual scan executions)
CREATE TABLE scans (
    id INTEGER PRIMARY KEY,
    scan_name TEXT NOT NULL UNIQUE, -- e.g. 'scan_20260716_001'
    scan_type TEXT,                 -- 'passive', 'active', 'full'
    scan_status TEXT,               -- 'running', 'completed', 'failed'
    started_at TEXT NOT NULL,       -- ISO 8601 string (e.g., '2026-07-02 14:00:00')
    completed_at TEXT,              -- ISO 8601 string
    scan_target TEXT,
    metadata JSON
);

CREATE INDEX idx_scans_scan_id ON scans(scan_name);

-- Assets (logical nodes - domains, subdomains, endpoints, etc.)
CREATE TABLE assets (
    id INTEGER PRIMARY KEY,
    asset_type TEXT NOT NULL,       -- 'domain', 'subdomain', 'endpoint', etc.
    asset_name TEXT NOT NULL,
    source JSON,                    -- Methods/tools that discovered this asset
    first_seen TEXT NOT NULL,       -- ISO 8601 string
    last_seen TEXT NOT NULL,        -- ISO 8601 string
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    UNIQUE(asset_type, asset_name)
);

CREATE INDEX idx_assets_type ON assets(asset_type);
CREATE INDEX idx_assets_name ON assets(asset_name, is_active);
CREATE INDEX idx_assets_active ON assets(is_active);

-- IP Addresses (separated from main assets)
CREATE TABLE ips (
    id INTEGER PRIMARY KEY,
    ip_address TEXT NOT NULL UNIQUE,
    first_seen TEXT NOT NULL,       -- ISO 8601 string
    last_seen TEXT NOT NULL,        -- ISO 8601 string
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE INDEX idx_ips_address ON ips(ip_address, is_active);

-- Asset <-> IP mappings
CREATE TABLE ip_mappings (
    asset_id INTEGER NOT NULL,
    ip_id INTEGER NOT NULL,
    first_seen TEXT NOT NULL,       -- ISO 8601 string
    last_seen TEXT NOT NULL,        -- ISO 8601 string
    last_scan_id INTEGER NOT NULL,  -- Which scan most recently verified this link
    source JSON,                    -- Which tool found this link
    is_active BOOLEAN DEFAULT 1,
    PRIMARY KEY (asset_id, ip_id),
    CONSTRAINT fk_ip_mappings_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ip_mappings_ip_id FOREIGN KEY (ip_id) REFERENCES ips(id) ON DELETE CASCADE,
    CONSTRAINT fk_ip_mappings_last_scan_id FOREIGN KEY (last_scan_id) REFERENCES scans(id) ON DELETE CASCADE
);

-- Reverse index
CREATE INDEX idx_ip_mappings_reverse ON ip_mappings(ip_id, is_active, asset_id);

-- Asset <-> Asset relationships
CREATE TABLE relationships (
    from_asset_id INTEGER NOT NULL,
    to_asset_id INTEGER NOT NULL,
    type TEXT NOT NULL,             -- i.e. "subdomain"
    source JSON,
    first_seen TEXT NOT NULL,       -- ISO 8601 string   
    last_seen TEXT NOT NULL,        -- ISO 8601 string
    is_active BOOLEAN DEFAULT 1 NOT NULL,
    metadata JSON,
    PRIMARY KEY (from_asset_id, to_asset_id),
    CONSTRAINT fk_relationships_from_asset_id FOREIGN KEY (from_asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_relationships_to_asset_id FOREIGN KEY (to_asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Reverse index
CREATE INDEX idx_relationships_reverse ON relationships(to_asset_id, is_active, from_asset_id);
CREATE INDEX idx_relationships_type ON relationships(type, is_active);

-- DNS Records
CREATE TABLE dns_records (
    id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,      -- The target domain
    record_type TEXT NOT NULL,      -- 'A', 'CNAME', etc.
    value TEXT NOT NULL,            -- The raw string value
    ttl INTEGER,
    priority INTEGER,
    first_seen TEXT NOT NULL,       -- ISO 8601 string
    last_seen TEXT NOT NULL,        -- ISO 8601 string
    is_current BOOLEAN DEFAULT 1 NOT NULL,      -- 1 if active, 0 if historical
    CONSTRAINT fk_dns_records_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Quickly reference current dns records
CREATE INDEX idx_dns_records_current_state ON dns_records(asset_id, record_type, value) WHERE is_current = 1;

-- Endpoints (path, parameters, api's, etc.)
CREATE TABLE endpoints (
    id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,      -- domain
    method TEXT NOT NULL,           -- 'GET', 'POST', 'PUT', etc.
    base_path TEXT NOT NULL,        -- Indexable base route (e.g., '/users')
    sub_path TEXT,                  -- The exact dynamic suffix/ID (e.g., '9999' or 'profile')
    query_params TEXT,              -- Optional: '?debug=true&admin=1'
    status_code INTEGER NOT NULL,   -- 200, 403, 404, etc.
    content_type TEXT,              -- 'application/json', 'text/html'
    response_hash TEXT,             -- MD5/SHA256 hash of the header/body to track shifts
    first_seen TEXT NOT NULL,       -- ISO 8601 string
    last_seen TEXT NOT NULL,        -- ISO 8601 string
    is_current BOOLEAN DEFAULT 1 NOT NULL,
    CONSTRAINT fk_endpoints_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Index for the Python State Machine Delta Check
CREATE INDEX idx_endpoints_current_state ON endpoints(asset_id, method, base_path, sub_path) WHERE is_current = 1;

-- Forensic Time Engine
CREATE INDEX idx_endpoints_time_bounds ON endpoints(first_seen, last_seen);

-- Base path lookup
CREATE INDEX idx_endpoints_lookup ON endpoints(asset_id, method, base_path) WHERE is_current = 1;

-- Scans <-> Assets Junction
CREATE TABLE scan_assets (
    scan_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, asset_id),
    CONSTRAINT fk_scan_assets_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_assets_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Reverse index
CREATE INDEX idx_scan_assets_reverse ON scan_assets(asset_id, scan_id);

-- Scans <-> IP Mappings Junction
CREATE TABLE scan_ip_mappings (
    scan_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    ip_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, asset_id, ip_id),
    CONSTRAINT fk_scan_ip_mappings_ip_map_id FOREIGN KEY (asset_id, ip_id) REFERENCES ip_mappings(asset_id, ip_id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_ip_mappings_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
);

-- Reverse index
CREATE INDEX idx_scan_ip_mappings ON scan_ip_mappings(asset_id, ip_id, scan_id);

-- Scans <-> Relationships Junction
CREATE TABLE scan_relationships (
    scan_id INTEGER NOT NULL,
    from_asset_id INTEGER NOT NULL,
    to_asset_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, from_asset_id, to_asset_id),
    CONSTRAINT fk_scan_relationships_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_relationships_rel_id FOREIGN KEY (from_asset_id, to_asset_id) REFERENCES relationships(from_asset_id, to_asset_id) ON DELETE CASCADE
);

-- Reverse index
CREATE INDEX idx_scan_relationships_reverse ON scan_relationships(from_asset_id, to_asset_id, scan_id);
