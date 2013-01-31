#ifndef UTILS_H
#define UTILS_H

#include <math.h>
// various utility structs and such

// 3d vector
struct fl3 {
	union {
		struct {
			float x, y, z;
		};
		float xyz[3];
	};
	fl3() : x(0), y(0), z(0) {};
	fl3(const fl3 &other) : x(other.x), y(other.y), z(other.z) {};
	fl3(const float nx, const float ny, const float nz) : x(nx), y(ny), z(nz) {};
	void fl3::normalize() 
	{
		float magnitude = sqrt(x*x + y*y + z*z);
		if (magnitude == 0) 
			return;
		x /= magnitude;
		y /= magnitude;
		z /= magnitude;
	};
	fl3 fl3::operator*(const float &scalar)
	{
		return fl3(x*scalar, y*scalar, z*scalar);
	};
	fl3 fl3::operator+(const fl3 &other)
	{
		return fl3(x+other.x, y+other.y, z+other.z);
	}
	fl3& fl3::operator+=(const fl3 &other)
	{
		x+=other.x; y+=other.y; z+=other.z;
		return *this;
	}
};

// 2d vector
struct fl2 {
	union {
		struct {
			float x, y;
		};
		struct {
			float s, t;
		};
		float xy[2];
		float st[2];
	};
	fl2() : x(0), y(0) {};
	fl2(const fl2 &other) : x(other.x), y(other.y) {};
	fl2(const float nx, const float ny) : x(nx), y(ny) {};
	fl2 fl2::operator+(const fl2 &other)
	{
		return fl2(x+other.x, y+other.y);
	}
	fl2& fl2::operator+=(const fl2 &other)
	{
		x+=other.x; y+=other.y;
		return *this;
	}
};

// integer vector
struct int2 {
	union {
		struct {
			int x, y;
		};
		int xy[2];
	};
	int2() : x(0), y(0) {};
	int2(const int2 &other) : x(other.x), y(other.y) {};
	int2(const int nx, const int ny) : x(nx), y(ny) {};
	int2 int2::operator+(const int2 &other)
	{
		return int2(x+other.x, y+other.y);
	};
	int2 int2::operator-(const int2 &other)
	{
		return int2(x-other.x, y-other.y);
	};
};

struct int3 {
	union {
		struct {
			int x, y, z;
		};
		int xyz[3];
	};
	int3() : x(0), y(0), z(0) {};
	int3(const int3 &other) : x(other.x), y(other.y), z(other.z) {};
	int3(const float nx, const float ny, const float nz) : x(nx), y(ny), z(nz) {};
	int3 int3::operator+(const int3 &other)
	{
		return int3(x+other.x, y+other.y, z+other.z);
	}
	
	friend bool operator< (const int3 &first, const int3 &second);
};

// compare operator for use as a map key weak ordering
static bool operator< (const int3 &first, const int3 &second)
{
	return (first.x < second.x) && (first.y < second.y) && (first.z < second.z);
}

#endif // UTILS_H