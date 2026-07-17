-- =====================================================
-- FodderMap brain.db Schema
-- =====================================================

-- Projects (lightweight metadata for self-documentation)
CREATE TABLE projects (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    created_at TEXT NOT NULL,
    last_updated TEXT NOT NULL,
    metadata JSON
);

-- Scans (track individual scan executions)
CREATE TABLE scans (
    id INTEGER PRIMARY KEY,
    scan_id TEXT UNIQUE NOT NULL,           -- e.g. 'scan_20260716_001'
    scan_type TEXT,                         -- 'passive', 'active', 'full'
    status TEXT,                            -- 'running', 'completed', 'failed'
    started_at TEXT NOT NULL,
    completed_at TEXT,
    target TEXT,
    metadata JSON
);

CREATE INDEX idx_scans_scan_id ON scans(scan_id);

-- Assets (logical nodes - domains, subdomains, endpoints, etc.)
CREATE TABLE assets (
    id INTEGER PRIMARY KEY,
    type TEXT NOT NULL,                     -- 'domain', 'subdomain', 'endpoint', etc.
    name TEXT NOT NULL,
    source JSON,                            -- Methods/tools that discovered this asset
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    UNIQUE(type, name)
);

CREATE INDEX idx_assets_type ON assets(type);
CREATE INDEX idx_assets_name ON assets(name);
CREATE INDEX idx_assets_active ON assets(is_active);

-- IP Addresses (separated from main assets)
CREATE TABLE ips (
    id INTEGER PRIMARY KEY,
    address TEXT UNIQUE NOT NULL,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE INDEX idx_ips_address ON ips(address);

-- Asset ↔ IP Mappings
CREATE TABLE ip_mappings (
    asset_id INTEGER NOT NULL,
    ip_id INTEGER NOT NULL,
    PRIMARY KEY (asset_id, ip_id),      -- Composite primary key
    source JSON,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_current BOOLEAN DEFAULT 1,
    metadata JSON,
    CONSTRAINT fk_ip_mappings_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ip_mappings_ip_id FOREIGN KEY (ip_id) REFERENCES ips(id) ON DELETE CASCADE
);

-- Create reverse index to complement the clustered index
CREATE INDEX idx_ip_asset_mapping ON ip_mappings(ip_id, asset_id);
CREATE INDEX idx_asset_ip_current ON ip_mappings(is_current);

-- Relationships (directed edges - logical focus)
CREATE TABLE relationships (
    id INTEGER PRIMARY KEY,
    from_asset_id INTEGER NOT NULL,
    to_asset_id INTEGER NOT NULL,
    type TEXT NOT NULL,                     -- 'subdomain', 'cname', 'a_record', etc.
    source JSON,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON,
    FOREIGN KEY (from_asset_id) REFERENCES assets(id),
    FOREIGN KEY (to_asset_id) REFERENCES assets(id)
);

CREATE INDEX idx_relationships_from ON relationships(from_asset_id);
CREATE INDEX idx_relationships_to ON relationships(to_asset_id);
CREATE INDEX idx_relationships_type ON relationships(type);
CREATE INDEX idx_relationships_active ON relationships(is_active);

-- DNS Records
CREATE TABLE dns_records (
    id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,
    record_type TEXT NOT NULL,
    value TEXT NOT NULL,
    priority INTEGER,
    ttl INTEGER,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    metadata JSON,
    FOREIGN KEY (asset_id) REFERENCES assets(id)
);

CREATE INDEX idx_dns_records_asset ON dns_records(asset_id);
CREATE INDEX idx_dns_records_type ON dns_records(record_type);

-- Endpoints (where real value lives)
CREATE TABLE endpoints (
    id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    status_code INTEGER,
    page_type TEXT,
    priority TEXT DEFAULT 'none',           -- 'none', 'low', 'medium', 'high', 'severe'
    is_redirect BOOLEAN DEFAULT 0,
    redirect_location TEXT,
    methods JSON,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    source JSON,
    metadata JSON,
    FOREIGN KEY (asset_id) REFERENCES assets(id)
);

CREATE INDEX idx_endpoints_asset ON endpoints(asset_id);
CREATE INDEX idx_endpoints_path ON endpoints(path);
CREATE INDEX idx_endpoints_status ON endpoints(status_code);
CREATE INDEX idx_endpoints_priority ON endpoints(priority);

CREATE TABLE scan_assets (
    scan_id INT UNSIGNED NOT NULL,
    asset_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (scan_id, asset_id),        -- Composite primary key
    CONSTRAINT fk_scan_assets_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_assets_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Create reverse index to complement the clustered index
CREATE INDEX idx_assets_scas ON scan_assets(asset_id, scan_id);