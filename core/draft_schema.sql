-- =====================================================
-- FodderMap brain.db Schema
-- =====================================================

-- ********************Summary**************************
-- 
-- Primary Tables:
-- **** projects
-- **** scans
-- **** assets
-- **** ips
-- **** ip_mappings (ips to assets / technically a junction)
-- **** relationships (assets to assets)
-- **** dns_records
-- **** endpoints
--
-- Junction Tables:
-- **** scan_assets (scans to assets)
-- **** scan_ips (scans to ips)
-- **** scan_ip_mappings (scans to ip mappings)
-- **** scan_relationships (scans to relationships)
-- **** scan_dns_records (scans to dns records)
-- **** scan_endpoints (scans to endpoints)
-- *****************************************************



-- Projects (lightweight metadata for self-documentation)
CREATE TABLE projects (
    id INTEGER PRIMARY KEY,
    project_name TEXT UNIQUE NOT NULL,
    created_at TEXT NOT NULL,
    last_updated TEXT NOT NULL,
    metadata JSON
);

-- Scans (track individual scan executions)
CREATE TABLE scans (
    id INTEGER PRIMARY KEY,
    scan_name TEXT UNIQUE NOT NULL,           -- e.g. 'scan_20260716_001'
    scan_type TEXT,                         -- 'passive', 'active', 'full'
    scan_status TEXT,                            -- 'running', 'completed', 'failed'
    started_at TEXT NOT NULL,
    completed_at TEXT,
    scan_target TEXT,
    metadata JSON
);

CREATE INDEX idx_scans_scan_id ON scans(scan_name);

-- Assets (logical nodes - domains, subdomains, endpoints, etc.)
CREATE TABLE assets (
    id INTEGER PRIMARY KEY,
    asset_type TEXT NOT NULL,                     -- 'domain', 'subdomain', 'endpoint', etc.
    asset_name TEXT NOT NULL,
    source JSON,                            -- Methods/tools that discovered this asset
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
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
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    metadata JSON
);

CREATE INDEX idx_ips_address ON ips(ip_address, is_active);

-- Asset <-> IP Mappings
CREATE TABLE ip_mappings (
    asset_id INTEGER NOT NULL,
    ip_id INTEGER NOT NULL,
    PRIMARY KEY (asset_id, ip_id),      -- Composite primary key
    source JSON,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_current BOOLEAN DEFAULT 1 NOT NULL,
    metadata JSON,
    CONSTRAINT fk_ip_mappings_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ip_mappings_ip_id FOREIGN KEY (ip_id) REFERENCES ips(id) ON DELETE CASCADE
);

-- Create reverse index to complement the clustered index
CREATE INDEX idx_ip_asset_mapping_reverse ON ip_mappings(ip_id, is_current, asset_id);

-- Relationships (directed edges - logical focus)
CREATE TABLE relationships (
    from_asset_id INTEGER NOT NULL,
    to_asset_id INTEGER NOT NULL,
    PRIMARY KEY (from_asset_id, to_asset_id),
    type TEXT NOT NULL,                     -- 'subdomain', 'cname', 'a_record', etc.
    source JSON,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1 NOT NULL,
    metadata JSON,
    CONSTRAINT relationships_from_asset_id FOREIGN KEY (from_asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT relationships_to_asset_id FOREIGN KEY (to_asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Create reverse index
CREATE INDEX idx_relationships_to_asset_id_reverse ON relationships(to_asset_id, is_active, from_asset_id);
CREATE INDEX idx_relationships_type ON relationships(type, is_active, from_asset_id, to_asset_id);

-- DNS Records
CREATE TABLE dns_records (
    id INTEGER PRIMARY KEY,
    asset_id INTEGER NOT NULL,
    record_type TEXT NOT NULL,          -- A, CNAME, etc.
    value TEXT NOT NULL,
    priority INTEGER,
    ttl INTEGER,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    metadata JSON,
    FOREIGN KEY (asset_id) REFERENCES assets(id)
);

CREATE INDEX idx_dns_records_asset ON dns_records(asset_id, record_type);
CREATE INDEX idx_dns_records_type ON dns_records(record_type, asset_id);

CREATE TABLE endpoints (
    asset_id INTEGER NOT NULL,
    path_name TEXT NOT NULL UNIQUE,
    PRIMARY KEY (asset_id, path_name),
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
    CONSTRAINT fk_endpoints_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

CREATE INDEX idx_endpoints_path ON endpoints(path_name, is_active, asset_id);
CREATE INDEX idx_endpoints_status ON endpoints(status_code, is_active, asset_id);
CREATE INDEX idx_endpoints_priority ON endpoints(priority, is_active, asset_id);


-- *****************Junction Tables*********************

CREATE TABLE scan_assets (
    scan_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, asset_id),        -- Composite primary key
    CONSTRAINT fk_scan_assets_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_assets_asset_id FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
);

-- Create reverse index to complement the clustered index
CREATE INDEX idx_scan_assets ON scan_assets(asset_id, scan_id);

CREATE TABLE scan_ips (
    scan_id INTEGER NOT NULL,
    ip_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, ip_id),
    CONSTRAINT fk_scan_ips_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_ips_ip_id FOREIGN KEY (ip_id) REFERENCES ips(id) ON DELETE CASCADE
);

CREATE INDEX idx_scan_ips ON scan_ips(ip_id, scan_id);

CREATE TABLE scan_ip_mappings (
    scan_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    ip_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, asset_id, ip_id),
    CONSTRAINT fk_scan_ip_mappings_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_ip_mappings_ip_map_id FOREIGN KEY (asset_id, ip_id) REFERENCES ip_mappings(asset_id, ip_id) ON DELETE CASCADE
);

CREATE INDEX idx_scan_ip_mappings_reverse ON scan_ip_mappings (asset_id, ip_id, scan_id);

CREATE TABLE scan_relationships (
    scan_id INTEGER NOT NULL, 
    from_asset_id INTEGER NOT NULL, 
    to_asset_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, from_asset_id, to_asset_id),
    CONSTRAINT fk_scan_relationships_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_relationships_rel_id FOREIGN KEY (from_asset_id, to_asset_id) REFERENCES relationships(from_asset_id, to_asset_id) ON DELETE CASCADE
);

CREATE INDEX idx_scan_relationships_reverse ON scan_relationships (from_asset_id, to_asset_id, scan_id);

CREATE TABLE scan_dns_records (
    scan_id INTEGER NOT NULL, 
    dns_id INTEGER NOT NULL,
    PRIMARY KEY (scan_id, dns_id),
    CONSTRAINT fk_scan_dns_records_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_dns_records_dns_id FOREIGN KEY (dns_id) REFERENCES dns_records(id) ON DELETE CASCADE
);

CREATE INDEX idx_scan_dns_records_reverse ON scan_dns_records (dns_id, scan_id);

CREATE TABLE scan_endpoints (
    scan_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    path_name TEXT NOT NULL UNIQUE,
    PRIMARY KEY (scan_id, asset_id, path_name),
    CONSTRAINT fk_scan_endpoints_scan_id FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_endpoints_end_id FOREIGN KEY (asset_id, path_name) REFERENCES endpoints(asset_id, path_name) ON DELETE CASCADE
);

CREATE INDEX idx_scan_endpoints_reverse ON scan_endpoints(asset_id, path_name, scan_id);