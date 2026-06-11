import uuid
import random
from datetime import datetime, timedelta
import math

# Naypyidaw Starting focal points
START_LOCATIONS = [
    (19.745, 96.129), # Myoma Market Area
    (19.760, 96.090), # Junction Centre Area
    (19.730, 96.150), # Tha Pyay Gone Area
]

# Rider UUIDs mapped from your database
RIDERS = [
    '3fabe3dc-6cd0-4830-b6d4-602df1a287da', # The Flash
    'dc4858e3-72f8-4819-b5ee-77c7acd47ec7', # Spider Noir
    '22222222-2222-2222-2222-222222222222'  # Speedy Rider 1
]

def add_meters_to_lat_lon(lat, lon, dy, dx):
    # 1 degree of latitude is ~111,320 meters
    new_lat = lat + (dy / 111320.0)
    # 1 degree of longitude is ~111,320 * cos(latitude) meters
    new_lon = lon + (dx / (111320.0 * math.cos(math.radians(lat))))
    return new_lat, new_lon

sql_inserts = []
# Assuming today is June 11, 2026. Start date goes back 1 week
start_date = datetime(2026, 6, 4, 8, 0, 0)

for rider in RIDERS:
    for day_offset in range(7): # 7 days
        current_day = start_date + timedelta(days=day_offset)

        # 2 to 3 routes per day
        num_routes = random.randint(2, 3)
        for route_idx in range(num_routes):
            route_start_time = current_day + timedelta(hours=random.randint(0, 10), minutes=random.randint(0, 59))

            # Start location + slight geographical randomness
            current_lat, current_lon = random.choice(START_LOCATIONS)
            current_lat += random.uniform(-0.01, 0.01)
            current_lon += random.uniform(-0.01, 0.01)

            # Simulated tracked points inside a given route
            num_points = random.randint(10, 20)
            direction = random.uniform(0, 2 * math.pi)

            for point_idx in range(num_points):
                point_id = str(uuid.uuid4())
                created_at = route_start_time + timedelta(minutes=point_idx * 2)

                sql = f"('{point_id}', '{rider}', {current_lat:.7f}, {current_lon:.7f}, '{created_at.strftime('%Y-%m-%d %H:%M:%S.%f+00')}', null)"
                sql_inserts.append(sql)

                # Move ~150 meters with natural noise
                noise = random.uniform(-math.pi/6, math.pi/6)
                move_dir = direction + noise
                dx = 150 * math.cos(move_dir)
                dy = 150 * math.sin(move_dir)

                current_lat, current_lon = add_meters_to_lat_lon(current_lat, current_lon, dy, dx)

# Batch insert for Supabase optimization
batch_size = 100
final_sqls = []
for i in range(0, len(sql_inserts), batch_size):
    batch = sql_inserts[i:i+batch_size]
    final_sqls.append('INSERT INTO "public"."rider_locations" ("id", "rider_id", "latitude", "longitude", "created_at", "provider") VALUES ' + ', '.join(batch) + ';')

# Output to Seeder file
with open('seeder_rider_locations.sql', 'w') as f:
    f.write('\n'.join(final_sqls))

print(f"Successfully generated {len(sql_inserts)} rows in seeder_rider_locations.sql")