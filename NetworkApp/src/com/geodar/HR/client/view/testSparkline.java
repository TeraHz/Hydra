package com.geodar.HR.client.view;

import com.google.gwt.core.client.GWT;
import com.google.gwt.http.client.Request;
import com.google.gwt.http.client.RequestBuilder;
import com.google.gwt.http.client.RequestCallback;
import com.google.gwt.http.client.RequestException;
import com.google.gwt.http.client.Response;
import com.google.gwt.http.client.URL;
import com.google.gwt.json.client.JSONArray;
import com.google.gwt.json.client.JSONException;
import com.google.gwt.json.client.JSONNumber;
import com.google.gwt.json.client.JSONObject;
import com.google.gwt.json.client.JSONParser;
import com.google.gwt.json.client.JSONValue;
import com.google.gwt.user.client.Timer;
import com.google.gwt.user.client.Window;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.visualization.client.AbstractDataTable.ColumnType;
import com.google.gwt.visualization.client.DataTable;
import com.google.gwt.visualization.client.VisualizationUtils;
import com.google.gwt.visualization.client.visualizations.ImageSparklineChart;

public class testSparkline extends VerticalPanel {

	private ImageSparklineChart gauge;
	private ImageSparklineChart.Options options;
	private String url;
	private DataTable data;
	private Timer timer;
	private RequestBuilder builder;

	public testSparkline(String query, String title, final int start, final int end) {

		this.url = URL.encode("http://" + Window.Location.getHost() + Configuration.StatusChartURL + query);
		GWT.log(this.url);
		builder = new RequestBuilder(RequestBuilder.GET, this.url);

		Runnable onLoadCallback = new Runnable() {

			public void run() {

				options = ImageSparklineChart.Options.create();
				options.setShowAxisLines(false);
				options.setShowValueLabels(false);
				options.setLabelPosition("left");

				// options.setGreenRange(start+10, end-10);
				// options.setYellowRange(start, end);

				getData();

				timer = new Timer() {

					public void run() {
						updateGraph();

						// GWT.log("tick");
					}

				};
				timer.scheduleRepeating(Configuration.GaugeRefresh);
				gauge = new ImageSparklineChart(data, options);
				add(gauge);

			}

		};

		VisualizationUtils.loadVisualizationApi(onLoadCallback, ImageSparklineChart.PACKAGE);
	}

	private void getData() {
		data = DataTable.create();
		// data.addColumn(ColumnType.STRING, "Category");
		data.addColumn(ColumnType.NUMBER, "Value");
		data.addColumn(ColumnType.NUMBER, "Revenue");
	    data.addColumn(ColumnType.NUMBER, "Licenses");
	    data.addRows(10);
	    data.setValue(0, 0, 435);
	    data.setValue(1, 0, 438);
	    data.setValue(2, 0, 512);
	    data.setValue(3, 0, 460);
	    data.setValue(4, 0, 491);
	    data.setValue(5, 0, 487);
	    data.setValue(6, 0, 552);
	    data.setValue(7, 0, 511);
	    data.setValue(8, 0, 505);
	    data.setValue(9, 0, 509);

	    data.setValue(0, 1, 132);
	    data.setValue(1, 1, 131);
	    data.setValue(2, 1, 137);
	    data.setValue(3, 1, 142);
	    data.setValue(4, 1, 140);
	    data.setValue(5, 1, 139);
	    data.setValue(6, 1, 147);
	    data.setValue(7, 1, 146);
	    data.setValue(8, 1, 151);
	    data.setValue(9, 1, 149);


		updateGraph();

	}

	public void setUpdateInterval(int ms) {
		timer.scheduleRepeating(ms);

	}

	private void updateGraph() {

		try {
			builder.sendRequest(null, new RequestCallback() {
				public void onError(Request request, Throwable exception) {
					GWT.log("Couldn't retrieve JSON");
				}

				public void onResponseReceived(Request request, Response response) {
					if (200 == response.getStatusCode()) {
						try {
							// parse the response text into JSON
							JSONValue jsonValue = JSONParser.parseStrict(response.getText());
							JSONArray jsonArray = jsonValue.isArray();

							if (jsonArray != null) {
								updateTable(jsonArray);
							} else {
								throw new JSONException();
							}
						} catch (JSONException e) {

							GWT.log("Could not parse JSON");
							GWT.log(e.toString());

							// e.printStackTrace();
						}
					} else {
						GWT.log("Couldn't retrieve JSON (" + response.getStatusText() + ")");
					}
				}

			});
		} catch (RequestException e) {
			GWT.log("Couldn't retrieve JSON");
		} catch (Exception e) {
			GWT.log(e.toString());
		}
	}

	private void updateTable(JSONArray array) {
		JSONValue jsonValue;

		data.removeRows(0, data.getNumberOfRows());
		for (int i = 0; i < array.size(); i++) {
			JSONObject jsEntry;
			JSONNumber jsVal;

			if ((jsEntry = array.get(i).isObject()) == null) {
				continue;
			}
			if ((jsonValue = jsEntry.get("value")) == null) {
				continue;
			}

			if ((jsVal = jsonValue.isNumber()) == null) {
				continue;
			}

			data.addRow();
			data.setValue(data.getNumberOfRows() - 1, 0, jsVal.doubleValue());
		}
		gauge.draw(data);
	}
	// @SuppressWarnings("deprecation")
	// private Date getDate(String str){
	// String[] a = str.split(" ");
	// String[] b = a[0].split("-");
	// String[] c = a[1].split(":");
	// int year, month, day, hrs, min, sec;
	// try{
	// year = Integer.parseInt(b[0]);
	// month = Integer.parseInt(b[1]);
	// day = Integer.parseInt(b[2]);
	// hrs = Integer.parseInt(c[0]);
	// min = Integer.parseInt(c[1]);
	// sec = Integer.parseInt(c[2]);
	// }catch(Exception e){
	// return new Date();
	// }
	// return new Date(year - 1900, month-1, day, hrs, min, sec);
	// }
}