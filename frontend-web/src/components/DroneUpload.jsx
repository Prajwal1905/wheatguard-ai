import React from "react";

export default function DroneUpload({
  file,
  setFile,
  location,
  setLocation,
  onUseMyLocation,
}) {
  const handleFileChange = (e) => {
    const f = e.target.files?.[0];
    if (f) {
      setFile(f);
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 md:p-5 space-y-4">
      <h2 className="text-base md:text-lg font-semibold mb-1">
        Drone Image Upload
      </h2>
      <p className="text-xs md:text-sm text-gray-500 mb-2">
        Use any field image as a simulated drone capture. The model will detect
        wheat disease and map it to the field location.
      </p>

      <div className="space-y-2">
        <label className="block text-xs font-medium text-gray-600">
          Image file
        </label>
        <input
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          className="block w-full text-sm text-gray-700 file:mr-4 file:py-2 file:px-3 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-emerald-50 file:text-emerald-700 hover:file:bg-emerald-100 cursor-pointer"
        />
        {file && (
          <p className="text-[11px] text-gray-500">
            Selected: <span className="font-medium">{file.name}</span>
          </p>
        )}
      </div>

      <div className="space-y-2">
        <label className="block text-xs font-medium text-gray-600">
          Field location (lat, lon)
        </label>
        <div className="grid grid-cols-2 gap-2">
          <input
            type="number"
            step="0.000001"
            placeholder="Latitude"
            value={location.lat}
            onChange={(e) =>
              setLocation((prev) => ({ ...prev, lat: e.target.value }))
            }
            className="border border-gray-200 rounded-md px-2 py-1.5 text-xs md:text-sm focus:outline-none focus:ring-1 focus:ring-emerald-500 focus:border-emerald-500"
          />
          <input
            type="number"
            step="0.000001"
            placeholder="Longitude"
            value={location.lon}
            onChange={(e) =>
              setLocation((prev) => ({ ...prev, lon: e.target.value }))
            }
            className="border border-gray-200 rounded-md px-2 py-1.5 text-xs md:text-sm focus:outline-none focus:ring-1 focus:ring-emerald-500 focus:border-emerald-500"
          />
        </div>
        <button
          type="button"
          onClick={onUseMyLocation}
          className="inline-flex items-center gap-1.5 mt-1 text-[11px] md:text-xs text-emerald-700 hover:text-emerald-800"
        >
          📍 Use my current location
        </button>
      </div>

      <div className="text-[11px] text-gray-400 border-t border-gray-100 pt-2">
        Tip: In real deployment, GPS will come from drone telemetry. For demo
        and testing, you can manually set lat/lon or use browser location.
      </div>
    </div>
  );
}
