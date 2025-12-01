/**
* This file is part of ORB-SLAM2.
*
* Copyright (C) 2014-2016 Raúl Mur-Artal <raulmur at unizar dot es> (University of Zaragoza)
* For more information see <https://github.com/raulmur/ORB_SLAM2>
*
* ORB-SLAM2 is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* ORB-SLAM2 is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with ORB-SLAM2. If not, see <http://www.gnu.org/licenses/>.
*/
#ifndef INITIALIZER_H
#define INITIALIZER_H

#include<opencv2/opencv.hpp>
#include "Frame.h"


namespace ORB_SLAM2
{

// THIS IS THE INITIALIZER FOR MONOCULAR SLAM. NOT USED IN THE STEREO OR RGBD CASE.
class Initializer
{
    typedef pair<int,int> Match;

public:

    // Structure to store initialization attempts (ORB-SLAM3 style)
    struct InitAttempt {
        cv::Mat R21;
        cv::Mat t21;
        vector<cv::Point3f> vP3D;
        vector<bool> vbTriangulated;
        float score;
        float parallax;
        int nTriangulated;
        bool bIsHomography;

        InitAttempt() : score(0.0f), parallax(0.0f), nTriangulated(0), bIsHomography(false) {}
    };

    // Fix the reference frame
    Initializer(const Frame &ReferenceFrame, float sigma = 1.0, int iterations = 200);

    // Computes in parallel a fundamental matrix and a homography
    // Selects a model and tries to recover the motion and the structure from motion
    bool Initialize(const Frame &CurrentFrame, const vector<int> &vMatches12,
                    cv::Mat &R21, cv::Mat &t21, vector<cv::Point3f> &vP3D, vector<bool> &vbTriangulated);

    // Get best initialization from all attempts (public for Tracking access)
    bool GetBestInitialization(cv::Mat &R21, cv::Mat &t21,
                              vector<cv::Point3f> &vP3D,
                              vector<bool> &vbTriangulated);

    // Store of initialization attempts (public for Tracking access)
    vector<InitAttempt> mvInitAttempts;


private:

    void FindHomography(vector<bool> &vbMatchesInliers, float &score, cv::Mat &H21);
    void FindFundamental(vector<bool> &vbInliers, float &score, cv::Mat &F21);

    cv::Mat ComputeH21(const vector<cv::Point2f> &vP1, const vector<cv::Point2f> &vP2);
    cv::Mat ComputeF21(const vector<cv::Point2f> &vP1, const vector<cv::Point2f> &vP2);

    float CheckHomography(const cv::Mat &H21, const cv::Mat &H12, vector<bool> &vbMatchesInliers, float sigma);

    float CheckFundamental(const cv::Mat &F21, vector<bool> &vbMatchesInliers, float sigma);

    bool ReconstructF(vector<bool> &vbMatchesInliers, cv::Mat &F21, cv::Mat &K,
                      cv::Mat &R21, cv::Mat &t21, vector<cv::Point3f> &vP3D, vector<bool> &vbTriangulated, float minParallax, int minTriangulated);

    bool ReconstructH(vector<bool> &vbMatchesInliers, cv::Mat &H21, cv::Mat &K,
                      cv::Mat &R21, cv::Mat &t21, vector<cv::Point3f> &vP3D, vector<bool> &vbTriangulated, float minParallax, int minTriangulated);

    void Triangulate(const cv::KeyPoint &kp1, const cv::KeyPoint &kp2, const cv::Mat &P1, const cv::Mat &P2, cv::Mat &x3D);

    void Normalize(const vector<cv::KeyPoint> &vKeys, vector<cv::Point2f> &vNormalizedPoints, cv::Mat &T);

    int CheckRT(const cv::Mat &R, const cv::Mat &t, const vector<cv::KeyPoint> &vKeys1, const vector<cv::KeyPoint> &vKeys2,
                       const vector<Match> &vMatches12, vector<bool> &vbInliers,
                       const cv::Mat &K, vector<cv::Point3f> &vP3D, float th2, vector<bool> &vbGood, float &parallax);

    void DecomposeE(const cv::Mat &E, cv::Mat &R1, cv::Mat &R2, cv::Mat &t);

    // ORB-SLAM3 style improvements
    // Improved model selection using symmetric transfer error
    bool SelectModel(const cv::Mat &H21, const cv::Mat &F21,
                     float SH, float SF,
                     bool &bUseHomography);

    // Compute symmetric transfer error for homography
    float ComputeSymmetricTransferError(const cv::Mat &H21, const cv::Mat &H12);

    // Check if scene is planar based on reconstructed 3D points
    bool IsScenePlanar(const vector<cv::Point3f> &vP3D, const vector<bool> &vbTriangulated);

    // Compute quality score for initialization
    float ComputeInitializationQuality(const cv::Mat &R21, const cv::Mat &t21,
                                        const vector<cv::Point3f> &vP3D,
                                        const vector<bool> &vbTriangulated,
                                        float parallax);

    // Save initialization attempt for later comparison
    void SaveInitAttempt(const cv::Mat &R21, const cv::Mat &t21,
                         const vector<cv::Point3f> &vP3D,
                         const vector<bool> &vbTriangulated,
                         float score, float parallax,
                         int nTriangulated, bool bIsHomography);


    // Keypoints from Reference Frame (Frame 1)
    vector<cv::KeyPoint> mvKeys1;

    // Keypoints from Current Frame (Frame 2)
    vector<cv::KeyPoint> mvKeys2;

    // Current Matches from Reference to Current
    vector<Match> mvMatches12;
    vector<bool> mvbMatched1;

    // Calibration
    cv::Mat mK;

    // Standard Deviation and Variance
    float mSigma, mSigma2;

    // Ransac max iterations
    int mMaxIterations;

    // Ransac sets
    vector<vector<size_t> > mvSets;

    // Configuration parameters
    float mfHFThreshold;           // Homography/Fundamental selection threshold (default 0.45)
    float mfMinParallax;           // Minimum parallax in degrees (default 1.0)
    int mnMinTriangulated;         // Minimum triangulated points (default 50)

};

} //namespace ORB_SLAM

#endif // INITIALIZER_H
