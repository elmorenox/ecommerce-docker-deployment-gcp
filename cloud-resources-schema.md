# Infrastructure Description Schema

## Overview
This schema provides a standardized way to describe cloud infrastructure components. It uses a flat structure that lists all resources at the root level.

## Schema Structure

### Root Element
```json
{
  "Resources": [] 
}
```

### Resource Types
Resources are defined with these standard attributes:
- `Type`: Primary classification (VPC, Compute, Database, etc.)
- `Count`: Number of instances required
- `Subtype`: Specific classification for certain resource types
- Additional attributes based on resource type (e.g., InstanceType for EC2)

### Resource Categories

1. **Network Resources**
   - VPC
   - AvailabilityZone
   - Subnet (with Subtype Public/Private)

2. **Compute Resources**
   - Type: Compute
   - Subtype: EC2
   - Additional attributes:
     - InstanceType (e.g., t2.micro, t3.micro)

3. **Database Resources**
   - Type: Database
   - For Managed Databases:
     - Subtype: RDS, Aurora, etc.
     - Engine: postgres, mysql, mariadb, etc.
   - For Non-Managed Databases:
     - Subtype: Direct database type (MongoDB, Cassandra, etc.)

## Schema Rules

1. **Required Fields**
   - Type
   - Count

2. **Optional Fields**
   - Subtype (required for certain Types)
   - InstanceType (for Compute resources)
   - Engine (for Database resources)

## Example Usage

```json
{
  "Resources": [
    {
      "Type": "VPC",
      "Count": 1
    },
    {
      "Type": "AvailabilityZone",
      "Count": 2
    },
    {
      "Type": "Subnet",
      "Subtype": "Public",
      "Count": 2
    },
    {
      "Type": "Compute",
      "Subtype": "EC2",
      "InstanceType": "t2.micro",
      "Count": 1
    },
    {
      "Type": "Database",
      "Subtype": "RDS",
      "Engine": "postgres",
      "Count": 1
    }
  ]
}
```