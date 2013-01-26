#include "camera.h"
#include "constants.h"
#include <math.h>

Camera::Camera() : rot_(), pos_(), fovy_(0), aspect_(0), zNear_(0), zFar_(0)
{
	
}

Camera::Camera(double fovy, double aspect, double zNear, double zFar)
{
	init(fovy, aspect, zNear, zFar);
}

Camera::~Camera()
{
	
}

void Camera::init(double fovy, double aspect, double zNear, double zFar)
{
	fovy_ = fovy;
	aspect_ = aspect;
	zNear_ = zNear;
	zFar_ = zFar;
}

void Camera::toMatrixAll(MatrixStack &mstack)
{
	toMatrixPj(mstack);
	toMatrixMv(mstack);
}

void Camera::toMatrixPj(MatrixStack &mstack)
{
	double xmin, xmax, ymin, ymax;
	ymax = zNear_ * tan(fovy_ * M_PI / 360.0);
	ymin = -ymax;
	xmin = ymin * aspect_;
	xmax = ymax * aspect_;
	mstack.loadIdentity(MatrixStack::PROJECTION);
	mstack.frustum(xmin, xmax, ymin, ymax, zNear_, zFar_);
}

void Camera::toMatrixMv(MatrixStack &mstack)
{
	mstack.loadIdentity(MatrixStack::MODELVIEW);
	mstack.rotate(rot_.x, 1, 0, 0);
	mstack.rotate(rot_.y, 0, 1, 0);
	mstack.translate(-pos_.x, -pos_.y, -pos_.z);
}

Camera& Camera::move(fl3 &tomove)
{
	pos_.x += -tomove.z * sin(DEGTORAD(rot_.y)) + tomove.x * cos(DEGTORAD(rot_.y));
	pos_.z += -tomove.z * cos(DEGTORAD(rot_.y)) + tomove.x * sin(DEGTORAD(rot_.y));
	pos_.y += tomove.y;
	return *this;
}

Camera& Camera::rotate(fl2 &torot)
{
	rot_ += torot;
	// limit pitch to -90 to 90
	rot_.x = min(90, max(-90, rot_.x));
	// limit left/right to -180 to 180 to prevent overflow
	if (rot_.y > 180) {
		rot_.y = rot_.y - 360;
	} else if (rot_.y < -180) {
		rot_.y = rot_.y + 360;
	}
	return *this;
}

Camera& Camera::setRot(fl2 &newrot)
{
	rot_ = newrot;
	return *this;
}

Camera& Camera::setPos(fl3 &newpos)
{
	pos_ = newpos;
	return *this;
}