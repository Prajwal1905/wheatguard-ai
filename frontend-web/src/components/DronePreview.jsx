import React from "react";

export default function DronePreview({
  file,
  previewUrl,
  location,
  onAnalyze,
  onClear,
  isAnalyzing,
}) {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 md:p-5 flex flex-col md:flex-row gap-4 md:gap-6">
      
      <div className="w-full md:w-1/3">
        <h2 className="text-sm font-semibold mb-2">Preview</h2>
        <div className="border border-dashed border-gray-200 rounded-lg h-48 flex items-center justify-center bg-gray-50 overflow-hidden">
          {previewUrl ? (
            <img
              src={previewUrl}
              alt="Drone preview"
              className="object-cover w-full h-full"
            />
          ) : (
            <span className="text-xs text-gray-400 text-center px-4">
              No image selected yet. Choose a drone snapshot on the left.
            </span>
          )}
        </div>
        {file && (
          <button
            type="button"
            onClick={onClear}
            className="mt-2 text-xs text-red-500 hover:text-red-600"
          >
            ✖ Clear image
          </button>
        )}
      </div>

      <div className="flex-1 space-y-3">
        <h2 className="text-sm font-semibold">Analysis Summary</h2>

        <div className="grid grid-cols-2 gap-3 text-xs md:text-sm">
          <div className="bg-gray-50 rounded-md px-3 py-2">
            <div className="text-gray-500 text-[11px]">Latitude</div>
            <div className="font-medium">
              {location.lat || <span className="text-gray-400">Not set</span>}
            </div>
          </div>
          <div className="bg-gray-50 rounded-md px-3 py-2">
            <div className="text-gray-500 text-[11px]">Longitude</div>
            <div className="font-medium">
              {location.lon || <span className="text-gray-400">Not set</span>}
            </div>
          </div>
        </div>

        <p className="text-[11px] text-gray-500">
          The image and coordinates will be sent to the AI model. Detected
          disease, severity and remedy will appear below and the detection will
          also show up on the Live Map in real time.
        </p>

        <div className="flex flex-wrap gap-2 mt-1">
          <button
            type="button"
            onClick={onAnalyze}
            disabled={isAnalyzing || !file}
            className={`inline-flex items-center justify-center px-4 py-1.5 rounded-md text-xs md:text-sm font-medium text-white transition
              ${
                isAnalyzing || !file
                  ? "bg-emerald-300 cursor-not-allowed"
                  : "bg-emerald-600 hover:bg-emerald-700"
              }`}
          >
            {isAnalyzing ? "Analyzing…" : "Analyze with AI"}
          </button>
          <span className="text-[11px] text-gray-400 self-center">
            Requires image + location.
          </span>
        </div>
      </div>
    </div>
  );
}
