#!/bin/sh
set -e

echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

SWIFT_STDLIB_PATH="${DT_TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"

install_framework()
{
  if [ -r "${BUILT_PRODUCTS_DIR}/$1" ]; then
    local source="${BUILT_PRODUCTS_DIR}/$1"
  elif [ -r "${BUILT_PRODUCTS_DIR}/$(basename "$1")" ]; then
    local source="${BUILT_PRODUCTS_DIR}/$(basename "$1")"
  elif [ -r "$1" ]; then
    local source="$1"
  fi

  local destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

  if [ -L "${source}" ]; then
      echo "Symlinked..."
      source="$(readlink "${source}")"
  fi

  # use filter instead of exclude so missing patterns dont' throw errors
  echo "rsync -av --filter \"- CVS/\" --filter \"- .svn/\" --filter \"- .git/\" --filter \"- .hg/\" --filter \"- Headers\" --filter \"- PrivateHeaders\" --filter \"- Modules\" \"${source}\" \"${destination}\""
  rsync -av --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" --filter "- Headers" --filter "- PrivateHeaders" --filter "- Modules" "${source}" "${destination}"

  local basename
  basename="$(basename -s .framework "$1")"
  binary="${destination}/${basename}.framework/${basename}"
  if ! [ -r "$binary" ]; then
    binary="${destination}/${basename}"
  fi

  # Strip invalid architectures so "fat" simulator / device frameworks work on device
  if [[ "$(file "$binary")" == *"dynamically linked shared library"* ]]; then
    strip_invalid_archs "$binary"
  fi

  # Resign the code if required by the build settings to avoid unstable apps
  code_sign_if_enabled "${destination}/$(basename "$1")"

  # Embed linked Swift runtime libraries. No longer necessary as of Xcode 7.
  if [ "${XCODE_VERSION_MAJOR}" -lt 7 ]; then
    local swift_runtime_libs
    swift_runtime_libs=$(xcrun otool -LX "$binary" | grep --color=never @rpath/libswift | sed -E s/@rpath\\/\(.+dylib\).*/\\1/g | uniq -u  && exit ${PIPESTATUS[0]})
    for lib in $swift_runtime_libs; do
      echo "rsync -auv \"${SWIFT_STDLIB_PATH}/${lib}\" \"${destination}\""
      rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"
      code_sign_if_enabled "${destination}/${lib}"
    done
  fi
}

# Signs a framework with the provided identity
code_sign_if_enabled() {
  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" -a "${CODE_SIGNING_REQUIRED}" != "NO" -a "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
    # Use the current code_sign_identitiy
    echo "Code Signing $1 with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    local code_sign_cmd="/usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS} --preserve-metadata=identifier,entitlements '$1'"

    if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
      code_sign_cmd="$code_sign_cmd &"
    fi
    echo "$code_sign_cmd"
    eval "$code_sign_cmd"
  fi
}

# Strip invalid architectures
strip_invalid_archs() {
  binary="$1"
  # Get architectures for current file
  archs="$(lipo -info "$binary" | rev | cut -d ':' -f1 | rev)"
  stripped=""
  for arch in $archs; do
    if ! [[ "${VALID_ARCHS}" == *"$arch"* ]]; then
      # Strip non-valid architectures in-place
      lipo -remove "$arch" -output "$binary" "$binary" || exit 1
      stripped="$stripped $arch"
    fi
  done
  if [[ "$stripped" ]]; then
    echo "Stripped $binary of architectures:$stripped"
  fi
}


if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_framework "$BUILT_PRODUCTS_DIR/AFNetworking/AFNetworking.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ActionSheetPicker-3.0/ActionSheetPicker_3_0.framework"
  install_framework "$BUILT_PRODUCTS_DIR/BlocksKit/BlocksKit.framework"
  install_framework "$BUILT_PRODUCTS_DIR/CHTCollectionViewWaterfallLayout/CHTCollectionViewWaterfallLayout.framework"
  install_framework "$BUILT_PRODUCTS_DIR/CocoaSecurity/CocoaSecurity.framework"
  install_framework "$BUILT_PRODUCTS_DIR/Colours/Colours.framework"
  install_framework "$BUILT_PRODUCTS_DIR/DACircularProgress/DACircularProgress.framework"
  install_framework "$BUILT_PRODUCTS_DIR/DZNEmptyDataSet/DZNEmptyDataSet.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FBAllocationTracker/FBAllocationTracker.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FBMemoryProfiler/FBMemoryProfiler.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FBRetainCycleDetector/FBRetainCycleDetector.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FDFullscreenPopGesture/FDFullscreenPopGesture.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FLEX/FLEX.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FMDB/FMDB.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FXBlurView/FXBlurView.framework"
  install_framework "$BUILT_PRODUCTS_DIR/HJCornerRadius/HJCornerRadius.framework"
  install_framework "$BUILT_PRODUCTS_DIR/HYBImageCliped/HYBImageCliped.framework"
  install_framework "$BUILT_PRODUCTS_DIR/IQKeyboardManager/IQKeyboardManager.framework"
  install_framework "$BUILT_PRODUCTS_DIR/JDStatusBarNotification/JDStatusBarNotification.framework"
  install_framework "$BUILT_PRODUCTS_DIR/JPFPSStatus/JPFPSStatus.framework"
  install_framework "$BUILT_PRODUCTS_DIR/JSBadgeView/JSBadgeView.framework"
  install_framework "$BUILT_PRODUCTS_DIR/KVOController/KVOController.framework"
  install_framework "$BUILT_PRODUCTS_DIR/LBXScan/LBXScan.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MBProgressHUD/MBProgressHUD.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MJExtension/MJExtension.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MJRefresh/MJRefresh.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MMMaterialDesignSpinner/MMMaterialDesignSpinner.framework"
  install_framework "$BUILT_PRODUCTS_DIR/Masonry/Masonry.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ReactiveCocoa/ReactiveCocoa.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SAMKeychain/SAMKeychain.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SDWebImage/SDWebImage.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SSZipArchive/SSZipArchive.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SVProgressHUD/SVProgressHUD.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SocketRocket/SocketRocket.framework"
  install_framework "$BUILT_PRODUCTS_DIR/TTTAttributedLabel/TTTAttributedLabel.framework"
  install_framework "$BUILT_PRODUCTS_DIR/TXScrollLabelView/TXScrollLabelView.framework"
  install_framework "$BUILT_PRODUCTS_DIR/UICollectionViewLeftAlignedLayout/UICollectionViewLeftAlignedLayout.framework"
  install_framework "$BUILT_PRODUCTS_DIR/UIImage+ImageWithColor/UIImageWithColor.framework"
  install_framework "$BUILT_PRODUCTS_DIR/UITableView+FDTemplateLayoutCell/UITableView_FDTemplateLayoutCell.framework"
  install_framework "$BUILT_PRODUCTS_DIR/WZLBadge/WZLBadge.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYAsyncLayer/YYAsyncLayer.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYCache/YYCache.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYCategories/YYCategories.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYDispatchQueuePool/YYDispatchQueuePool.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYImage/YYImage.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYKeyboardManager/YYKeyboardManager.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYModel/YYModel.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYText/YYText.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYWebImage/YYWebImage.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ZBarSDK/ZBarSDK.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ZYCornerRadius/ZYCornerRadius.framework"
  install_framework "$BUILT_PRODUCTS_DIR/libextobjc/libextobjc.framework"
  install_framework "$BUILT_PRODUCTS_DIR/pop/pop.framework"
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_framework "$BUILT_PRODUCTS_DIR/AFNetworking/AFNetworking.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ActionSheetPicker-3.0/ActionSheetPicker_3_0.framework"
  install_framework "$BUILT_PRODUCTS_DIR/BlocksKit/BlocksKit.framework"
  install_framework "$BUILT_PRODUCTS_DIR/CHTCollectionViewWaterfallLayout/CHTCollectionViewWaterfallLayout.framework"
  install_framework "$BUILT_PRODUCTS_DIR/CocoaSecurity/CocoaSecurity.framework"
  install_framework "$BUILT_PRODUCTS_DIR/Colours/Colours.framework"
  install_framework "$BUILT_PRODUCTS_DIR/DACircularProgress/DACircularProgress.framework"
  install_framework "$BUILT_PRODUCTS_DIR/DZNEmptyDataSet/DZNEmptyDataSet.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FBAllocationTracker/FBAllocationTracker.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FBMemoryProfiler/FBMemoryProfiler.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FBRetainCycleDetector/FBRetainCycleDetector.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FDFullscreenPopGesture/FDFullscreenPopGesture.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FLEX/FLEX.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FMDB/FMDB.framework"
  install_framework "$BUILT_PRODUCTS_DIR/FXBlurView/FXBlurView.framework"
  install_framework "$BUILT_PRODUCTS_DIR/HJCornerRadius/HJCornerRadius.framework"
  install_framework "$BUILT_PRODUCTS_DIR/HYBImageCliped/HYBImageCliped.framework"
  install_framework "$BUILT_PRODUCTS_DIR/IQKeyboardManager/IQKeyboardManager.framework"
  install_framework "$BUILT_PRODUCTS_DIR/JDStatusBarNotification/JDStatusBarNotification.framework"
  install_framework "$BUILT_PRODUCTS_DIR/JPFPSStatus/JPFPSStatus.framework"
  install_framework "$BUILT_PRODUCTS_DIR/JSBadgeView/JSBadgeView.framework"
  install_framework "$BUILT_PRODUCTS_DIR/KVOController/KVOController.framework"
  install_framework "$BUILT_PRODUCTS_DIR/LBXScan/LBXScan.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MBProgressHUD/MBProgressHUD.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MJExtension/MJExtension.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MJRefresh/MJRefresh.framework"
  install_framework "$BUILT_PRODUCTS_DIR/MMMaterialDesignSpinner/MMMaterialDesignSpinner.framework"
  install_framework "$BUILT_PRODUCTS_DIR/Masonry/Masonry.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ReactiveCocoa/ReactiveCocoa.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SAMKeychain/SAMKeychain.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SDWebImage/SDWebImage.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SSZipArchive/SSZipArchive.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SVProgressHUD/SVProgressHUD.framework"
  install_framework "$BUILT_PRODUCTS_DIR/SocketRocket/SocketRocket.framework"
  install_framework "$BUILT_PRODUCTS_DIR/TTTAttributedLabel/TTTAttributedLabel.framework"
  install_framework "$BUILT_PRODUCTS_DIR/TXScrollLabelView/TXScrollLabelView.framework"
  install_framework "$BUILT_PRODUCTS_DIR/UICollectionViewLeftAlignedLayout/UICollectionViewLeftAlignedLayout.framework"
  install_framework "$BUILT_PRODUCTS_DIR/UIImage+ImageWithColor/UIImageWithColor.framework"
  install_framework "$BUILT_PRODUCTS_DIR/UITableView+FDTemplateLayoutCell/UITableView_FDTemplateLayoutCell.framework"
  install_framework "$BUILT_PRODUCTS_DIR/WZLBadge/WZLBadge.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYAsyncLayer/YYAsyncLayer.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYCache/YYCache.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYCategories/YYCategories.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYDispatchQueuePool/YYDispatchQueuePool.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYImage/YYImage.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYKeyboardManager/YYKeyboardManager.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYModel/YYModel.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYText/YYText.framework"
  install_framework "$BUILT_PRODUCTS_DIR/YYWebImage/YYWebImage.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ZBarSDK/ZBarSDK.framework"
  install_framework "$BUILT_PRODUCTS_DIR/ZYCornerRadius/ZYCornerRadius.framework"
  install_framework "$BUILT_PRODUCTS_DIR/libextobjc/libextobjc.framework"
  install_framework "$BUILT_PRODUCTS_DIR/pop/pop.framework"
fi
if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
  wait
fi
