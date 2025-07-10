import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View, Image, Dimensions } from 'react-native';
import { Magnetometer } from 'expo-sensors';
import * as Location from 'expo-location';

export default function App() {
  const [heading, setHeading] = useState(0);
  const [location, setLocation] =
    useState<Location.LocationObjectCoords | null>(null);
  const [gridLocator, setGridLocator] = useState<string | null>(null);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
  const [updateTime, setUpdateTime] = useState<number | null>(null);
  const [locationError, setLocationError] = useState<string | null>(null);

  // Compass heading
  useEffect(() => {
    const sub = Magnetometer.addListener((data) => {
      const angle = calculateHeading(data);
      setHeading(angle);
    });
    return () => sub.remove();
  }, []);

  // Live GPS location
  useEffect(() => {
    let watcher: Location.LocationSubscription | null = null;

    const startWatching = async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setLocationError('Permission to access location was denied');
        return;
      }

      watcher = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.BestForNavigation,
          timeInterval: 5000,
          distanceInterval: 5,
        },
        (pos) => {
          const t0 = Date.now();
          const { coords } = pos;

          const maiden = latLonToMaiden8(coords.latitude, coords.longitude);
          const formatted =
            maiden.slice(0, 2).toUpperCase() + // Field (e.g., JO)
            maiden.slice(2, 4) + // Square (e.g., 52)
            maiden.slice(4, 6).toLowerCase() + // Subsquare (e.g., gf)
            maiden.slice(6, 8); // Extended square (e.g., 76)

          setLocation(coords);
          setGridLocator(formatted);
          setLastUpdate(new Date(pos.timestamp));
          setUpdateTime(Date.now() - t0);
        },
      );
    };

    startWatching();
    return () => {
      if (watcher) watcher.remove();
    };
  }, []);

  const calculateHeading = (data: {
    x: number;
    y: number;
    z: number;
  }): number => {
    const { x, y } = data;
    let angle = Math.atan2(-y, x) * (180 / Math.PI);
    angle = angle >= 0 ? angle : 360 + angle;
    return Math.round(angle);
  };

  const getDirection = (angle: number): string => {
    if (angle >= 337 || angle <= 22) return 'N';
    if (angle > 22 && angle <= 67) return 'NE';
    if (angle > 67 && angle <= 112) return 'E';
    if (angle > 112 && angle <= 157) return 'SE';
    if (angle > 157 && angle <= 202) return 'S';
    if (angle > 202 && angle <= 247) return 'SW';
    if (angle > 247 && angle <= 292) return 'W';
    if (angle > 292 && angle < 337) return 'NW';
    return '';
  };

  // ✅ Correct Maidenhead Grid Locator Calculation
  const latLonToMaiden8 = (lat: number, lon: number): string => {
    lon += 180;
    lat += 90;

    const A = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const a = 'abcdefghijklmnopqrstuvwxyz';

    const lonField = Math.floor(lon / 20);
    const latField = Math.floor(lat / 10);

    const lonSquare = Math.floor((lon % 20) / 2);
    const latSquare = Math.floor((lat % 10) / 1);

    const lonSub = Math.floor(((lon % 2) / 2) * 24);
    const latSub = Math.floor((lat % 1) * 24);

    const lonExt = Math.floor((((lon * 60) % 2) * 60) / 5); // 0–9
    const latExt = Math.floor((((lat * 60) % 2.5) * 60) / 5); // 0–9

    return (
      A[lonField] +
      A[latField] +
      lonSquare.toString() +
      latSquare.toString() +
      a[lonSub] +
      a[latSub] +
      lonExt.toString() +
      latExt.toString()
    );
  };

  return (
    <View style={styles.container}>
      <Text style={styles.text}>Heading: {heading}°</Text>
      <Text style={styles.text}>Direction: {getDirection(heading)}</Text>

      <View style={styles.compassContainer}>
        <Image
          source={{
            uri: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Compass_rose_en.svg/512px-Compass_rose_en.svg.png',
          }}
          style={[
            styles.compass,
            { transform: [{ rotate: `${-heading}deg` }] },
          ]}
        />
      </View>

      {location ? (
        <>
          <Text style={styles.location}>
            Latitude: {location.latitude.toFixed(5)}
          </Text>
          <Text style={styles.location}>
            Longitude: {location.longitude.toFixed(5)}
          </Text>
          <Text style={styles.grid}>Grid: {gridLocator}</Text>
          <Text style={styles.info}>
            Last Update: {lastUpdate?.toLocaleTimeString()}
          </Text>
          <Text style={styles.info}>Update Time: {updateTime ?? '?'} ms</Text>
          <Text style={styles.info}>
            Accuracy: ±{location.accuracy?.toFixed(1)} m
          </Text>
        </>
      ) : locationError ? (
        <Text style={styles.error}>{locationError}</Text>
      ) : (
        <Text style={styles.location}>Fetching location…</Text>
      )}
    </View>
  );
}

const size = Dimensions.get('window').width * 0.7;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#111',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
  },
  text: {
    color: '#0f0',
    fontSize: 22,
    marginBottom: 10,
  },
  location: {
    color: '#0ff',
    fontSize: 16,
    marginTop: 5,
  },
  grid: {
    color: '#ff0',
    fontSize: 18,
    marginTop: 5,
    fontWeight: 'bold',
  },
  info: {
    color: '#aaa',
    fontSize: 14,
    marginTop: 2,
  },
  error: {
    color: 'red',
    fontSize: 16,
    marginTop: 5,
  },
  compassContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    width: size,
    height: size,
    marginVertical: 20,
  },
  compass: {
    width: '100%',
    height: '100%',
    resizeMode: 'contain',
  },
});
