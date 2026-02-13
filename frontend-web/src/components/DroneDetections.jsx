import React from "react";

export default function DroneDetections({ lastResult, history }) {
  const detection = lastResult?.detection;
  const result = lastResult?.result || lastResult; 

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 md:p-5 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm md:text-base font-semibold">
           Drone Detection Result
        </h2>
        <span className="text-[11px] text-gray-400">
          Latest + recent detections
        </span>
      </div>

      
      {result ? (
        <div className="border border-emerald-100 rounded-lg p-3 md:p-4 bg-emerald-50/40 space-y-2 text-xs md:text-sm">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <div className="text-gray-500 text-[11px]">Disease</div>
              <div className="font-semibold text-emerald-800">
                {result.label || detection?.disease}
              </div>
            </div>
            <div>
              <div className="text-gray-500 text-[11px]">Severity</div>
              <span
                className={`inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-medium ${
                  (result.severity || detection?.severity) === "high"
                    ? "bg-red-100 text-red-700"
                    : (result.severity || detection?.severity) === "medium"
                    ? "bg-amber-100 text-amber-700"
                    : "bg-green-100 text-green-700"
                }`}
              >
                {result.severity || detection?.severity}
              </span>
            </div>
            <div>
              <div className="text-gray-500 text-[11px]">Confidence</div>
              <div className="font-medium">
                {result.confidence || detection?.confidence || "-"}%
              </div>
            </div>
          </div>

          {detection && (
            <div className="grid grid-cols-2 gap-2 mt-2">
              <div>
                <div className="text-gray-500 text-[11px]">Lat</div>
                <div className="font-medium text-gray-800">
                  {detection.lat ?? "-"}
                </div>
              </div>
              <div>
                <div className="text-gray-500 text-[11px]">Lon</div>
                <div className="font-medium text-gray-800">
                  {detection.lon ?? "-"}
                </div>
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="text-xs text-gray-400">
          No drone analysis run yet. Upload an image and click{" "}
          <span className="font-semibold">Analyze with AI</span>.
        </div>
      )}

      
      {history && history.length > 0 && (
        <div className="pt-2 border-t border-gray-100">
          <h3 className="text-xs font-semibold text-gray-600 mb-2">
            Recent Drone Detections
          </h3>
          <div className="overflow-x-auto">
            <table className="min-w-full text-[11px] md:text-xs">
              <thead>
                <tr className="text-left text-gray-500 border-b border-gray-100">
                  <th className="py-1.5 pr-3">Disease</th>
                  <th className="py-1.5 px-3">Severity</th>
                  <th className="py-1.5 px-3">Conf.</th>
                  <th className="py-1.5 px-3">Lat</th>
                  <th className="py-1.5 px-3">Lon</th>
                  <th className="py-1.5 pl-3">Time</th>
                </tr>
              </thead>
              <tbody>
                {history.map((d, idx) => (
                  <tr
                    key={d.id || idx}
                    className="border-b border-gray-50 last:border-0"
                  >
                    <td className="py-1.5 pr-3">
                      {d.disease || d.disease_label}
                    </td>
                    <td className="py-1.5 px-3">
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-[10px] font-medium ${
                          d.severity === "high" || d.severity === "High"
                            ? "bg-red-100 text-red-700"
                            : d.severity === "medium" ||
                              d.severity === "Medium"
                            ? "bg-amber-100 text-amber-700"
                            : "bg-green-100 text-green-700"
                        }`}
                      >
                        {d.severity}
                      </span>
                    </td>
                    <td className="py-1.5 px-3">
                      {d.confidence ? `${d.confidence.toFixed(1)}%` : "-"}
                    </td>
                    <td className="py-1.5 px-3">
                      {d.lat ? d.lat.toFixed?.(4) ?? d.lat : "-"}
                    </td>
                    <td className="py-1.5 px-3">
                      {d.lon ? d.lon.toFixed?.(4) ?? d.lon : "-"}
                    </td>
                    <td className="py-1.5 pl-3 text-[10px] text-gray-400">
                      {d.timestamp
                        ? new Date(d.timestamp).toLocaleString()
                        : "-"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
