// A minimal Vulkan layer that logs the render passes of every presented
// frame to logcat (tag "ImpellerPasses"):
//
//   device 1 frame 123: 3 passes: 1080x2424x4 280x200x4 135x100x1
//
// one entry per vkCmdBeginRenderPass recorded on that device since its
// previous present: render area and the sample count of the pass's first
// attachment (4 = an MSAA EntityPass, 1 = a filter pass or the onscreen
// copy). Impeller's Vulkan builds carry no debug labels, so passes are told
// apart by size and sample count. Android loads GPU debug layers into every
// Vulkan user of the app (HWUI too), so all state is per instance/device.
//
// Load it into a debuggable app (see tool/validate_android.dart).
#include <android/log.h>
#include <vulkan/vk_layer.h>
#include <vulkan/vulkan.h>

#include <cstring>
#include <mutex>
#include <string>
#include <unordered_map>

#define LOG(...) \
  __android_log_print(ANDROID_LOG_INFO, "ImpellerPasses", __VA_ARGS__)

namespace {
constexpr char kLayerName[] = "VK_LAYER_impeller_pass_logger";

void* Key(const void* dispatchable) {
  return *reinterpret_cast<void* const*>(dispatchable);
}

struct InstanceData {
  PFN_vkGetInstanceProcAddr gipa;
  VkInstance instance;
};

struct DeviceData {
  int id;
  PFN_vkGetDeviceProcAddr gdpa;
  PFN_vkCreateRenderPass create_render_pass;
  PFN_vkCreateRenderPass2 create_render_pass2;
  PFN_vkCmdBeginRenderPass begin;
  PFN_vkCmdBeginRenderPass2 begin2;
  PFN_vkQueuePresentKHR present;
  std::unordered_map<uint64_t, int> samples;
  std::string frame;
  int count = 0;
  uint64_t frames = 0;
};

std::mutex g_mutex;
std::unordered_map<void*, InstanceData> g_instances;
std::unordered_map<void*, DeviceData> g_devices;
int g_next_device_id = 0;

DeviceData& Device(const void* handle) { return g_devices.at(Key(handle)); }

void Record(const void* cb, VkRenderPass rp, const VkRect2D& area) {
  std::lock_guard<std::mutex> lock(g_mutex);
  auto& d = Device(cb);
  auto it = d.samples.find(reinterpret_cast<uint64_t>(rp));
  int samples = it == d.samples.end() ? 0 : it->second;
  d.frame += " " + std::to_string(area.extent.width) + "x" +
             std::to_string(area.extent.height) + "x" +
             std::to_string(samples);
  d.count++;
}

VKAPI_ATTR VkResult VKAPI_CALL CreateRenderPass(
    VkDevice device, const VkRenderPassCreateInfo* info,
    const VkAllocationCallbacks* alloc, VkRenderPass* out) {
  PFN_vkCreateRenderPass next;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    next = Device(device).create_render_pass;
  }
  VkResult r = next(device, info, alloc, out);
  if (r == VK_SUCCESS && info->attachmentCount > 0) {
    std::lock_guard<std::mutex> lock(g_mutex);
    Device(device).samples[reinterpret_cast<uint64_t>(*out)] =
        info->pAttachments[0].samples;
  }
  return r;
}

VKAPI_ATTR VkResult VKAPI_CALL CreateRenderPass2(
    VkDevice device, const VkRenderPassCreateInfo2* info,
    const VkAllocationCallbacks* alloc, VkRenderPass* out) {
  PFN_vkCreateRenderPass2 next;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    next = Device(device).create_render_pass2;
  }
  VkResult r = next(device, info, alloc, out);
  if (r == VK_SUCCESS && info->attachmentCount > 0) {
    std::lock_guard<std::mutex> lock(g_mutex);
    Device(device).samples[reinterpret_cast<uint64_t>(*out)] =
        info->pAttachments[0].samples;
  }
  return r;
}

VKAPI_ATTR void VKAPI_CALL CmdBeginRenderPass(VkCommandBuffer cb,
                                              const VkRenderPassBeginInfo* info,
                                              VkSubpassContents contents) {
  Record(cb, info->renderPass, info->renderArea);
  PFN_vkCmdBeginRenderPass next;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    next = Device(cb).begin;
  }
  next(cb, info, contents);
}

VKAPI_ATTR void VKAPI_CALL CmdBeginRenderPass2(
    VkCommandBuffer cb, const VkRenderPassBeginInfo* info,
    const VkSubpassBeginInfo* sub) {
  Record(cb, info->renderPass, info->renderArea);
  PFN_vkCmdBeginRenderPass2 next;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    next = Device(cb).begin2;
  }
  next(cb, info, sub);
}

VKAPI_ATTR VkResult VKAPI_CALL QueuePresentKHR(VkQueue queue,
                                               const VkPresentInfoKHR* info) {
  PFN_vkQueuePresentKHR next;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto& d = Device(queue);
    LOG("device %d frame %llu: %d passes:%s", d.id,
        (unsigned long long)d.frames++, d.count, d.frame.c_str());
    d.frame.clear();
    d.count = 0;
    next = d.present;
  }
  return next(queue, info);
}

VKAPI_ATTR VkResult VKAPI_CALL CreateInstance(const VkInstanceCreateInfo* info,
                                              const VkAllocationCallbacks* alloc,
                                              VkInstance* instance) {
  auto* link = reinterpret_cast<VkLayerInstanceCreateInfo*>(
      const_cast<void*>(info->pNext));
  while (link &&
         !(link->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO &&
           link->function == VK_LAYER_LINK_INFO)) {
    link = reinterpret_cast<VkLayerInstanceCreateInfo*>(
        const_cast<void*>(link->pNext));
  }
  if (!link) return VK_ERROR_INITIALIZATION_FAILED;
  PFN_vkGetInstanceProcAddr gipa = link->u.pLayerInfo->pfnNextGetInstanceProcAddr;
  link->u.pLayerInfo = link->u.pLayerInfo->pNext;
  auto create = reinterpret_cast<PFN_vkCreateInstance>(
      gipa(VK_NULL_HANDLE, "vkCreateInstance"));
  VkResult r = create(info, alloc, instance);
  if (r == VK_SUCCESS) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_instances[Key(*instance)] = {gipa, *instance};
  }
  return r;
}

VKAPI_ATTR VkResult VKAPI_CALL CreateDevice(VkPhysicalDevice gpu,
                                            const VkDeviceCreateInfo* info,
                                            const VkAllocationCallbacks* alloc,
                                            VkDevice* device) {
  auto* link =
      reinterpret_cast<VkLayerDeviceCreateInfo*>(const_cast<void*>(info->pNext));
  while (link && !(link->sType == VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO &&
                   link->function == VK_LAYER_LINK_INFO)) {
    link = reinterpret_cast<VkLayerDeviceCreateInfo*>(
        const_cast<void*>(link->pNext));
  }
  if (!link) return VK_ERROR_INITIALIZATION_FAILED;
  PFN_vkGetInstanceProcAddr gipa = link->u.pLayerInfo->pfnNextGetInstanceProcAddr;
  PFN_vkGetDeviceProcAddr gdpa = link->u.pLayerInfo->pfnNextGetDeviceProcAddr;
  link->u.pLayerInfo = link->u.pLayerInfo->pNext;
  auto create =
      reinterpret_cast<PFN_vkCreateDevice>(gipa(VK_NULL_HANDLE, "vkCreateDevice"));
  VkResult r = create(gpu, info, alloc, device);
  if (r != VK_SUCCESS) return r;
  DeviceData d;
  d.gdpa = gdpa;
  d.create_render_pass = reinterpret_cast<PFN_vkCreateRenderPass>(
      gdpa(*device, "vkCreateRenderPass"));
  d.create_render_pass2 = reinterpret_cast<PFN_vkCreateRenderPass2>(
      gdpa(*device, "vkCreateRenderPass2"));
  if (!d.create_render_pass2) {
    d.create_render_pass2 = reinterpret_cast<PFN_vkCreateRenderPass2>(
        gdpa(*device, "vkCreateRenderPass2KHR"));
  }
  d.begin = reinterpret_cast<PFN_vkCmdBeginRenderPass>(
      gdpa(*device, "vkCmdBeginRenderPass"));
  d.begin2 = reinterpret_cast<PFN_vkCmdBeginRenderPass2>(
      gdpa(*device, "vkCmdBeginRenderPass2"));
  if (!d.begin2) {
    d.begin2 = reinterpret_cast<PFN_vkCmdBeginRenderPass2>(
        gdpa(*device, "vkCmdBeginRenderPass2KHR"));
  }
  d.present = reinterpret_cast<PFN_vkQueuePresentKHR>(
      gdpa(*device, "vkQueuePresentKHR"));
  std::lock_guard<std::mutex> lock(g_mutex);
  d.id = g_next_device_id++;
  LOG("device %d created", d.id);
  g_devices[Key(*device)] = std::move(d);
  return VK_SUCCESS;
}

VkLayerProperties MakeProps() {
  VkLayerProperties p{};
  strncpy(p.layerName, kLayerName, sizeof(p.layerName) - 1);
  p.specVersion = VK_MAKE_VERSION(1, 1, 0);
  p.implementationVersion = 1;
  strncpy(p.description, "Logs Impeller render passes per frame",
          sizeof(p.description) - 1);
  return p;
}

PFN_vkVoidFunction OwnDeviceFunction(const char* name) {
  if (!strcmp(name, "vkCreateRenderPass"))
    return (PFN_vkVoidFunction)CreateRenderPass;
  if (!strcmp(name, "vkCreateRenderPass2") ||
      !strcmp(name, "vkCreateRenderPass2KHR"))
    return (PFN_vkVoidFunction)CreateRenderPass2;
  if (!strcmp(name, "vkCmdBeginRenderPass"))
    return (PFN_vkVoidFunction)CmdBeginRenderPass;
  if (!strcmp(name, "vkCmdBeginRenderPass2") ||
      !strcmp(name, "vkCmdBeginRenderPass2KHR"))
    return (PFN_vkVoidFunction)CmdBeginRenderPass2;
  if (!strcmp(name, "vkQueuePresentKHR"))
    return (PFN_vkVoidFunction)QueuePresentKHR;
  return nullptr;
}
}  // namespace

extern "C" {

VKAPI_ATTR VkResult VKAPI_CALL
vkEnumerateInstanceLayerProperties(uint32_t* count, VkLayerProperties* props) {
  if (props && *count >= 1) props[0] = MakeProps();
  *count = 1;
  return VK_SUCCESS;
}

VKAPI_ATTR VkResult VKAPI_CALL vkEnumerateDeviceLayerProperties(
    VkPhysicalDevice, uint32_t* count, VkLayerProperties* props) {
  return vkEnumerateInstanceLayerProperties(count, props);
}

VKAPI_ATTR VkResult VKAPI_CALL vkEnumerateInstanceExtensionProperties(
    const char* layer, uint32_t* count, VkExtensionProperties*) {
  if (!layer || strcmp(layer, kLayerName) != 0)
    return VK_ERROR_LAYER_NOT_PRESENT;
  *count = 0;
  return VK_SUCCESS;
}

VKAPI_ATTR VkResult VKAPI_CALL vkEnumerateDeviceExtensionProperties(
    VkPhysicalDevice gpu, const char* layer, uint32_t* count,
    VkExtensionProperties* props) {
  if (layer && !strcmp(layer, kLayerName)) {
    *count = 0;
    return VK_SUCCESS;
  }
  // A physical device shares its instance's dispatch key.
  InstanceData data{};
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_instances.find(Key(gpu));
    if (it != g_instances.end()) data = it->second;
  }
  if (!data.gipa) return VK_ERROR_LAYER_NOT_PRESENT;
  auto next = reinterpret_cast<PFN_vkEnumerateDeviceExtensionProperties>(
      data.gipa(data.instance, "vkEnumerateDeviceExtensionProperties"));
  return next ? next(gpu, layer, count, props) : VK_ERROR_LAYER_NOT_PRESENT;
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL vkGetDeviceProcAddr(VkDevice device,
                                                              const char* name) {
  if (!strcmp(name, "vkGetDeviceProcAddr"))
    return (PFN_vkVoidFunction)vkGetDeviceProcAddr;
  if (auto own = OwnDeviceFunction(name)) return own;
  std::lock_guard<std::mutex> lock(g_mutex);
  auto it = g_devices.find(Key(device));
  return it == g_devices.end() ? nullptr : it->second.gdpa(device, name);
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL
vkGetInstanceProcAddr(VkInstance instance, const char* name) {
  if (!strcmp(name, "vkGetInstanceProcAddr"))
    return (PFN_vkVoidFunction)vkGetInstanceProcAddr;
  if (!strcmp(name, "vkCreateInstance"))
    return (PFN_vkVoidFunction)CreateInstance;
  if (!strcmp(name, "vkCreateDevice")) return (PFN_vkVoidFunction)CreateDevice;
  if (!strcmp(name, "vkGetDeviceProcAddr"))
    return (PFN_vkVoidFunction)vkGetDeviceProcAddr;
  if (!strcmp(name, "vkEnumerateInstanceLayerProperties"))
    return (PFN_vkVoidFunction)vkEnumerateInstanceLayerProperties;
  if (!strcmp(name, "vkEnumerateDeviceLayerProperties"))
    return (PFN_vkVoidFunction)vkEnumerateDeviceLayerProperties;
  if (!strcmp(name, "vkEnumerateDeviceExtensionProperties"))
    return (PFN_vkVoidFunction)vkEnumerateDeviceExtensionProperties;
  if (auto own = OwnDeviceFunction(name)) return own;
  if (!instance) return nullptr;
  std::lock_guard<std::mutex> lock(g_mutex);
  auto it = g_instances.find(Key(instance));
  return it == g_instances.end() ? nullptr : it->second.gipa(instance, name);
}
}
